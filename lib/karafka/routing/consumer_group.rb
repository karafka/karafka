# frozen_string_literal: true

module Karafka
  module Routing
    # Object used to describe a single consumer group that is going to subscribe to
    # given topics
    # It is a part of Karafka's DSL
    class ConsumerGroup
      extend Helpers::ConfigRetriever

      attr_reader :topics
      attr_reader :id

      # @param [String, Symbol] id of this consumer group
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
        config_retriever_for(attribute)
      end

      def to_h
        result = {
          topics: topics.map(&:to_h),
          id: id
        }

        Karafka::AttributesMap.consumer_group_attributes.each do |attribute|
          result[attribute] = public_send(attribute)
        end

        result
      end
    end
  end
end
