# frozen_string_literal: true

module Karafka
  module Routing
    # Object representing a set of single consumer group topics that can be subscribed together
    # with one connection.
    #
    # @note One subscription group will always belong to one consumer group, but one consumer
    #   group can have multiple subscription groups.
    class SubscriptionGroup
      attr_reader :id, :name, :topics, :kafka

      # @param position [Integer] position of this subscription group in all the subscriptions
      #   groups array. We need to have this value for sake of static group memberships, where
      #   we need a "in-between" restarts unique identifier
      # @param topics [Karafka::Routing::Topics] all the topics that share the same key settings
      # @return [SubscriptionGroup] built subscription group
      def initialize(position, topics)
        @name = topics.first.subscription_group
        @id = "#{@name}_#{position}"
        @position = position
        @topics = topics
        @kafka = build_kafka
        freeze
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
        sgs = Karafka::App.config.internal.routing.active.subscription_groups

        # When empty it means no groups were specified, hence all should be used
        sgs.empty? || sgs.include?(name)
      end

      private

      # @return [Hash] kafka settings are a bit special. They are exactly the same for all of the
      #   topics but they lack the group.id (unless explicitly) provided. To make it compatible
      #   with our routing engine, we inject it before it will go to the consumer
      def build_kafka
        kafka = Setup::AttributesMap.consumer(@topics.first.kafka.dup)

        # If we use static group memberships, there can be a case, where same instance id would
        # be set on many subscription groups as the group instance id from Karafka perspective is
        # set per config. Each instance even if they are subscribed to different topics needs to
        # have if fully unique. To make sure of that, we just add extra postfix at the end that
        # increments.
        group_instance_id = kafka.fetch(:'group.instance.id', false)

        kafka[:'group.instance.id'] = "#{group_instance_id}_#{@position}" if group_instance_id
        kafka[:'client.id'] ||= Karafka::App.config.client_id
        kafka[:'group.id'] ||= @topics.first.consumer_group.id
        kafka[:'auto.offset.reset'] ||= @topics.first.initial_offset
        # Karafka manages the offsets based on the processing state, thus we do not rely on the
        # rdkafka offset auto-storing
        kafka[:'enable.auto.offset.store'] = false
        kafka.freeze
        kafka
      end
    end
  end
end
