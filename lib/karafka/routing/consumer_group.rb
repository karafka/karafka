# frozen_string_literal: true

module Karafka
  module Routing
    # Object used to describe a single consumer group that is going to subscribe to
    # given topics
    # It is a part of Karafka's DSL
    class ConsumerGroup
      attr_reader :topics
      attr_reader :id

      # @param [String, Symbol] id of this consumer group
      # @yield Evalues given block in current consumer group context allowing to
      #   configure multiple kafka and karafka related options on a per consumer group basis
      def initialize(id, &block)
        @id = "#{Karafka::App.config.name.underscore}_#{id}"
        @topics = []
        instance_eval(&block)
      end

      # @param topic_name [String, Symbol] name of a topic from which we want to consumer
      # @yield Evaluates a given block in a topic context
      # @return [Karafka::Routing::Topic] newly built topic instance
      def topic(name, &block)
        @topics << Topic.new(name, self, &block).tap(&:build)
        @topics.last
      end

      Karafka::AttributesMap.consumer_group_attributes.each do |attribute|
        define_method attribute do |argument = nil|
          if argument.nil?
            current_value = instance_variable_get(:"@#{attribute}")
            return current_value unless current_value.nil?

            value = if Karafka::App.config.respond_to?(attribute)
              Karafka::App.config.public_send(attribute)
            else
              Karafka::App.config.kafka.public_send(attribute)
            end

            instance_variable_set(:"@#{attribute}", value)
          else
            instance_variable_set(:"@#{attribute}", argument)
          end
        end
      end
    end
  end
end
