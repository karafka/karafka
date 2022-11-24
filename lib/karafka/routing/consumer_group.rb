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

      # This is a "virtual" attribute that is not building subscription groups.
      # It allows us to store the "current" subscription group defined in the routing
      # This subscription group id is then injected into topics, so we can compute the subscription
      # groups
      attr_accessor :current_subscription_group_id

      # @param name [String, Symbol] raw name of this consumer group. Raw means, that it does not
      #   yet have an application client_id namespace, this will be added here by default.
      #   We add it to make a multi-system development easier for people that don't use
      #   kafka and don't understand the concept of consumer groups.
      def initialize(name)
        @name = name.to_s
        @id = Karafka::App.config.consumer_mapper.call(name)
        @topics = Topics.new([])
        # Initialize the subscription group so there's always a value for it, since even if not
        # defined directly, a subscription group will be created
        @current_subscription_group_id = SecureRandom.uuid
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
        built_topic = @topics.last
        # We overwrite it conditionally in case it was not set by the user inline in the topic
        # block definition
        built_topic.subscription_group ||= current_subscription_group_id
        built_topic
      end

      # Assigns the current subscription group id based on the defined one and allows for further
      # topic definition
      # @param name [String, Symbol]
      # @param block [Proc] block that may include topics definitions
      def subscription_group=(name, &block)
        # We cast it here, so the routing supports symbol based but that's anyhow later on
        # validated as a string
        @current_subscription_group_id = name

        Proxy.new(self, &block)

        # We need to reset the current subscription group after it is used, so it won't leak
        # outside to other topics that would be defined without a defined subscription group
        @current_subscription_group_id = SecureRandom.uuid
      end

      # @return [Array<Routing::SubscriptionGroup>] all the subscription groups build based on
      #   the consumer group topics
      def subscription_groups
        @subscription_groups ||= App
                                 .config
                                 .internal
                                 .routing
                                 .subscription_groups_builder
                                 .call(topics)
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
