# frozen_string_literal: true

module Karafka
  module Routing
    # Object representing a set of single consumer group topics that can be subscribed together
    # with one connection.
    #
    # @note One subscription group will always belong to one consumer group, but one consumer
    #   group can have multiple subscription groups.
    class SubscriptionGroup
      include Helpers::ConfigImporter.new(
        activity_manager: %i[internal routing activity_manager],
        client_id: %i[client_id],
        node: %i[swarm node]
      )

      attr_reader :id, :name, :topics, :kafka, :consumer_group

      # Lock for generating new ids safely
      ID_MUTEX = Mutex.new

      private_constant :ID_MUTEX

      class << self
        # Generates new subscription group id that will be used in case of anonymous subscription
        #   groups
        # @return [String] hex(6) compatible reproducible id
        def id
          ID_MUTEX.synchronize do
            @group_counter ||= 0
            @group_counter += 1

            ::Digest::SHA256.hexdigest(
              @group_counter.to_s
            )[0..11]
          end
        end
      end

      # @param position [Integer] position of this subscription group in all the subscriptions
      #   groups array. We need to have this value for sake of static group memberships, where
      #   we need a "in-between" restarts unique identifier
      # @param topics [Karafka::Routing::Topics] all the topics that share the same key settings
      # @return [SubscriptionGroup] built subscription group
      def initialize(position, topics)
        @details = topics.first.subscription_group_details
        @name = @details.fetch(:name)
        @consumer_group = topics.first.consumer_group
        # We include the consumer group id here because we want to have unique ids of subscription
        # groups across the system. Otherwise user could set the same name for multiple
        # subscription groups in many consumer groups effectively having same id for different
        # entities
        @id = "#{@consumer_group.id}_#{@name}_#{position}"
        @position = position
        @topics = topics
        @kafka = build_kafka
      end

      # @return [String] consumer group id
      def consumer_group_id
        kafka[:'group.id']
      end

      # @return [Integer] max messages fetched in a single go
      def max_messages
        @topics.first.max_messages
      end

      # @return [Integer] max milliseconds we can wait for incoming messages
      def max_wait_time
        @topics.first.max_wait_time
      end

      # @return [Boolean] is this subscription group one of active once
      def active?
        activity_manager.active?(:subscription_groups, name)
      end

      # @return [false, Array<String>] names of topics to which we should subscribe or false when
      #   operating only on direct assignments
      #
      # @note Most of the time it should not include inactive topics but in case of pattern
      #   matching the matcher topics become inactive down the road, hence we filter out so
      #   they are later removed.
      def subscriptions
        topics.select(&:active?).map(&:subscription_name)
      end

      # @param _consumer [Karafka::Connection::Proxy]
      # @return [false, Rdkafka::Consumer::TopicPartitionList] List of tpls for direct assignments
      #   or false for the normal mode
      def assignments(_consumer)
        false
      end

      # @return [String] id of the subscription group
      # @note This is an alias for displaying in places where we print the stringified version.
      def to_s
        id
      end

      # Refreshes the configuration of this subscription group if needed based on the execution
      # context.
      #
      # Since the initial routing setup happens in the supervisor, it is inherited by the children.
      # This causes incomplete assignment of `group.instance.id` which is not expanded with proper
      # node identifier. This refreshes this if needed when in swarm.
      def refresh
        return unless node
        return unless kafka.key?(:'group.instance.id')

        @kafka = build_kafka
      end

      private

      # @return [Hash] kafka settings are a bit special. They are exactly the same for all of the
      #   topics but they lack the group.id (unless explicitly) provided. To make it compatible
      #   with our routing engine, we inject it before it will go to the consumer
      def build_kafka
        kafka = Setup::AttributesMap.consumer(@topics.first.kafka.dup)

        inject_defaults(kafka)
        inject_group_instance_id(kafka)
        inject_client_id(kafka)

        kafka[:'group.id'] ||= @consumer_group.id
        kafka[:'auto.offset.reset'] ||= @topics.first.initial_offset
        # Karafka manages the offsets based on the processing state, thus we do not rely on the
        # rdkafka offset auto-storing
        kafka[:'enable.auto.offset.store'] = false
        kafka.freeze
        kafka
      end

      # Injects (if needed) defaults
      #
      # @param kafka [Hash] kafka level config
      def inject_defaults(kafka)
        Setup::DefaultsInjector.consumer(kafka)
      end

      # Sets (if needed) the client.id attribute
      #
      # @param kafka [Hash] kafka level config
      def inject_client_id(kafka)
        # If client id is set directly on librdkafka level, we do nothing and just go with what
        # end user has configured
        return if kafka.key?(:'client.id')

        # This mitigates an issue for multiplexing and potentially other cases when running
        # multiple karafka processes on one machine, where librdkafka goes into an infinite
        # loop when using cooperative-sticky and upscaling.
        #
        # @see https://github.com/confluentinc/librdkafka/issues/4783
        kafka[:'client.id'] = if kafka[:'partition.assignment.strategy'] == 'cooperative-sticky'
                                "#{client_id}/#{Time.now.to_f}/#{SecureRandom.hex[0..9]}"
                              else
                                client_id
                              end
      end

      # If we use static group memberships, there can be a case, where same instance id would
      # be set on many subscription groups as the group instance id from Karafka perspective is
      # set per config. Each instance even if they are subscribed to different topics needs to
      # have it fully unique. To make sure of that, we just add extra postfix at the end that
      # increments.
      #
      # We also handle a swarm case, where the same setup would run from many forked nodes, hence
      # affecting the instance id and causing conflicts
      # @param kafka [Hash] kafka level config
      def inject_group_instance_id(kafka)
        group_instance_prefix = kafka.fetch(:'group.instance.id', false)

        # If group instance id was not even configured, do nothing
        return unless group_instance_prefix

        # If there is a node, we need to take its id and inject it as well so multiple forks can
        # have different instances ids but they are reproducible
        components = [group_instance_prefix, node ? node.id : nil, @position]

        kafka[:'group.instance.id'] = components.compact.join('_')
      end
    end
  end
end
