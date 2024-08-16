# frozen_string_literal: true

module Karafka
  module Routing
    # Topic stores all the details on how we should interact with Kafka given topic.
    # It belongs to a consumer group as from 0.6 all the topics can work in the same consumer group
    # It is a part of Karafka's DSL.
    class Topic
      attr_reader :id, :name, :consumer_group
      attr_writer :consumer

      attr_accessor :subscription_group_details

      # Full subscription group reference can be built only when we have knowledge about the
      # whole routing tree, this is why it is going to be set later on
      attr_accessor :subscription_group

      # Attributes we can inherit from the root unless they were defined on this level
      INHERITABLE_ATTRIBUTES = %i[
        kafka
        max_messages
        max_wait_time
        initial_offset
        consumer_persistence
        pause_timeout
        pause_max_timeout
        pause_with_exponential_backoff
      ].freeze

      private_constant :INHERITABLE_ATTRIBUTES

      # @param [String, Symbol] name of a topic on which we want to listen
      # @param consumer_group [Karafka::Routing::ConsumerGroup] owning consumer group of this topic
      def initialize(name, consumer_group)
        @name = name.to_s
        @consumer_group = consumer_group
        @attributes = {}
        @active = true
        # @note We use identifier related to the consumer group that owns a topic, because from
        #   Karafka 0.6 we can handle multiple Kafka instances with the same process and we can
        #   have same topic name across multiple consumer groups
        @id = "#{consumer_group.id}_#{@name}"
      end

      INHERITABLE_ATTRIBUTES.each do |attribute|
        attr_writer attribute

        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{attribute}
            return @#{attribute} unless @#{attribute}.nil?

            @#{attribute} = Karafka::App.config.send(:#{attribute})
          end
        RUBY
      end

      # Often users want to have the same basic cluster setup with small setting alterations
      # This method allows us to do so by setting `inherit` to `true`. Whe inherit is enabled,
      # settings will be merged with defaults.
      #
      # @param settings [Hash] kafka scope settings. If `:inherit` key is provided, it will
      #   instruct the assignment to merge with root level defaults
      #
      # @note It is set to `false` by default to preserve backwards compatibility
      def kafka=(settings = {})
        inherit = settings.delete(:inherit)

        @kafka = inherit ? Karafka::App.config.kafka.merge(settings) : settings
      end

      # @return [String] name of subscription that will go to librdkafka
      def subscription_name
        name
      end

      # @return [Class] consumer class that we should use
      def consumer
        if consumer_persistence
          # When persistence of consumers is on, no need to reload them
          @consumer
        else
          # In order to support code reload without having to change the topic api, we re-fetch the
          # class of a consumer based on its class name. This will support all the cases where the
          # consumer class is defined with a name. It won't support code reload for anonymous
          # consumer classes, but this is an edge case
          begin
            ::Object.const_get(@consumer.to_s)
          rescue NameError
            # It will only fail if the in case of anonymous classes
            @consumer
          end
        end
      end

      # Allows to disable topic by invoking this method and setting it to `false`.
      # @param active [Boolean] should this topic be consumed or not
      def active(active)
        # Do not allow for active overrides. Basically if this is set on the topic level, defaults
        # will not overwrite it and this is desired. Otherwise because of the fact that this is
        # not a full feature config but just a flag, default value would always overwrite the
        # per-topic config since defaults application happens after the topic config block
        unless @active_assigned
          @active = active
          @active_assigned = true
        end

        @active
      end

      # @return [Class] consumer class that we should use
      # @note This is just an alias to the `#consumer` method. We however want to use it internally
      #   instead of referencing the `#consumer`. We use this to indicate that this method returns
      #   class and not an instance. In the routing we want to keep the `#consumer Consumer`
      #   routing syntax, but for references outside, we should use this one.
      def consumer_class
        consumer
      end

      # @return [Boolean] should this topic be in use
      def active?
        # Never active if disabled via routing
        return false unless @active

        Karafka::App.config.internal.routing.activity_manager.active?(:topics, name)
      end

      # @return [Hash] hash with all the topic attributes
      # @note This is being used when we validate the consumer_group and its topics
      def to_h
        map = INHERITABLE_ATTRIBUTES.map do |attribute|
          [attribute, public_send(attribute)]
        end

        Hash[map].merge!(
          id: id,
          name: name,
          active: active?,
          consumer: consumer,
          consumer_group_id: consumer_group.id,
          subscription_group_details: subscription_group_details
        ).freeze
      end
    end
  end
end
