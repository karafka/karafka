# frozen_string_literal: true

module Karafka
  module Routing
    # Object used to describe a single consumer group that is going to subscribe to
    # given topics
    # It is a part of Karafka's DSL
    # @note A single consumer group represents Kafka consumer group, but it may not match 1:1 with
    #   subscription groups. There can be more subscription groups than consumer groups
    class ConsumerGroup
      extend Helpers::ConfigRetriever

      attr_reader :id, :topics, :name

      # Attributes we can inherit from the root unless they were redefined on this level
      INHERITABLE_ATTRIBUTES = %w[
        kafka
        deserializer
        manual_offset_management
        max_messages
        max_wait_time
      ].freeze

      private_constant :INHERITABLE_ATTRIBUTES

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
      # @param block [Proc] block that we want to evaluate in the topic context
      # @return [Karafka::Routing::Topic] newly built topic instance
      def topic=(name, &block)
        topic = Topic.new(name, self)
        @topics << Proxy.new(topic, &block).target.tap(&:build)
        @topics.last
      end

      INHERITABLE_ATTRIBUTES.each do |attribute|
        config_retriever_for(attribute)
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
        result = {
          topics: topics.map(&:to_h),
          id: id
        }

        INHERITABLE_ATTRIBUTES.each do |attribute|
          result[attribute] = public_send(attribute)
        end

        result
      end
    end
  end
end
