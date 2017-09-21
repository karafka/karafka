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
      attr_reader :name

      # @param name [String, Symbol] raw name of this consumer group. Raw means, that it does not
      #   yet have an application client_id namespace, this will be added here by default.
      #   We add it to make a multi-system development easier for people that don't use
      #   kafka and don't understand the concept of consumer groups.
      def initialize(name)
        @name = name
        @id = Karafka::App.config.consumer_mapper.call(name)
        @topics = []
      end

      # @return [Boolean] true if this consumer group should be active in our current process
      def active?
        Karafka::Server.consumer_groups.include?(name)
      end

      # Builds a topic representation inside of a current consumer group route
      # @param name [String, Symbol] name of topic to which we want to subscribe
      # @yield Evaluates a given block in a topic context
      # @return [Karafka::Routing::Topic] newly built topic instance
      def topic=(name, &block)
        topic = Topic.new(name, self)
        @topics << Proxy.new(topic, &block).target.tap(&:build)
        @topics.last
      end

      Karafka::AttributesMap.consumer_group.each do |attribute|
        config_retriever_for(attribute)
      end

      # Hashed version of consumer group that can be used for validation purposes
      # @return [Hash] hash with consumer group attributes including serialized to hash
      # topics inside of it.
      def to_h
        result = {
          topics: topics.map(&:to_h),
          id: id
        }

        Karafka::AttributesMap.consumer_group.each do |attribute|
          result[attribute] = public_send(attribute)
        end

        result
      end
    end
  end
end
