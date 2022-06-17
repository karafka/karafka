# frozen_string_literal: true

module Karafka
  module Routing
    # Topic stores all the details on how we should interact with Kafka given topic.
    # It belongs to a consumer group as from 0.6 all the topics can work in the same consumer group
    # It is a part of Karafka's DSL.
    class Topic
      attr_reader :id, :name, :consumer_group
      attr_writer :consumer

      # Attributes we can inherit from the root unless they were defined on this level
      INHERITABLE_ATTRIBUTES = %i[
        kafka
        deserializer
        manual_offset_management
        max_messages
        max_wait_time
        initial_offset
      ].freeze

      private_constant :INHERITABLE_ATTRIBUTES

      # @param [String, Symbol] name of a topic on which we want to listen
      # @param consumer_group [Karafka::Routing::ConsumerGroup] owning consumer group of this topic
      def initialize(name, consumer_group)
        @name = name.to_s
        @consumer_group = consumer_group
        @attributes = {}
        # @note We use identifier related to the consumer group that owns a topic, because from
        #   Karafka 0.6 we can handle multiple Kafka instances with the same process and we can
        #   have same topic name across multiple consumer groups
        @id = "#{consumer_group.id}_#{@name}"
      end

      INHERITABLE_ATTRIBUTES.each do |attribute|
        attr_writer attribute

        define_method attribute do
          current_value = instance_variable_get(:"@#{attribute}")

          return current_value unless current_value.nil?

          value = Karafka::App.config.send(attribute)

          instance_variable_set(:"@#{attribute}", value)
        end
      end

      # @return [Class] consumer class that we should use
      def consumer
        if Karafka::App.config.consumer_persistence
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

      # @return [Boolean] true if this topic offset is handled by the end user
      def manual_offset_management?
        manual_offset_management
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
          consumer: consumer,
          consumer_group_id: consumer_group.id
        ).freeze
      end
    end
  end
end
