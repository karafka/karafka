# frozen_string_literal: true

module Karafka
  module Routing
    # Object used to describe a single consumer group that is going to subscribe to
    # given topics
    # It is a part of Karafka's DSL
    # @note A single consumer group represents Kafka consumer group, but it may not match 1:1 with
    #   subscription groups. There can be more subscription groups than consumer groups
    class ConsumerGroup
      attr_reader :id, :topics, :name

      # @param name [String, Symbol] raw name of this consumer group. Raw means, that it does not
      #   yet have an application client_id namespace, this will be added here by default.
      #   We add it to make a multi-system development easier for people that don't use
      #   kafka and don't understand the concept of consumer groups.
      def initialize(name)
        @name = name
        @id = Karafka::App.config.consumer_mapper.call(name)
        @topics = Topics.new([])
      end

      # @return [Boolean] true if this consumer group should be active in our current process
      def active?
        Karafka::Server.consumer_groups.include?(name)
      end

      # Builds a topic representation inside of a current consumer group route
      # @param name [String, Symbol] name of topic to which we want to subscribe
      # @param block [Proc] block that we want to evaluate in the topic context
      # @return [Karafka::Routing::Topic] newly built topic instance
      def topic=(name, &block)
        topic = Topic.new(name, self)
        @topics << Proxy.new(topic, &block).target
        @topics.last
      end

      # @return [Array<Routing::SubscriptionGroup>] all the subscription groups build based on
      #   the consumer group topics
      def subscription_groups
        App.config.internal.subscription_groups_builder.call(topics)
      end

      # Hashed version of consumer group that can be used for validation purposes
      # @return [Hash] hash with consumer group attributes including serialized to hash
      # topics inside of it.
      def to_h
        {
          topics: topics.map(&:to_h),
          id: id
        }.freeze
      end
    end
  end
end
