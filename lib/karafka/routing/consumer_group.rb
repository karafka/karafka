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
      def initialize(id)
        @id = "#{Karafka::App.config.name.to_s.underscore}_#{id}"
        @topics = []
      end

      # Builds a topic representation inside of a current consumer group route
      # @param topic_name [String, Symbol] name of a topic from which we want to consumer
      # @yield Evaluates a given block in a topic context
      # @param name [String, Symbol] name of topic to which we want to subscribe
      # @return [Karafka::Routing::Topic] newly built topic instance
      def topic=(name, &block)
        topic = Topic.new(name, self)
        @topics << Proxy.new(topic, &block).target.tap(&:build)
        @topics.last
      end

      Karafka::AttributesMap.consumer_group_attributes.each do |attribute|
        attr_writer attribute unless method_defined? :"#{attribute}="

        next if method_defined? attribute

        define_method attribute do
          current_value = instance_variable_get(:"@#{attribute}")
          return current_value unless current_value.nil?

          value = if Karafka::App.config.respond_to?(attribute)
            Karafka::App.config.public_send(attribute)
          else
            Karafka::App.config.kafka.public_send(attribute)
          end

          instance_variable_set(:"@#{attribute}", value)
        end
      end
    end
  end
end
