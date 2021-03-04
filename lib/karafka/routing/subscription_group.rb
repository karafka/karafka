# frozen_string_literal: true

module Karafka
  module Routing
    # Object representing a set of topics that can be subscribed together with one kafka connection
    class SubscriptionGroup
      attr_reader :id
      attr_reader :topics

      # @param [Array<Karafka::Routing::Topic>] all the topics that share the same kafka settings
      # @return [Karafka::Routing::SubscriptionGroup] built subscription group
      def initialize(topics)
        @id = SecureRandom.uuid
        @topics = topics
      end

      def max_messages
        consumer_group.max_messages
      end

      def max_wait_time
        consumer_group.max_wait_time
      end

      def consumer_group
        @topics.first.consumer_group
      end

      # @return [Hash] kafka settings are a bit special. They are exactly the same for all of the
      #   topics but they lack the group.id (unless explicitly) provided. To make it compatible
      #   with our routing engine, we inject it before it will go to the consumer
      def kafka
        kafka = @topics.first.kafka

        kafka['client.id'] ||= 'karafka'
        kafka['group.id'] ||= consumer_group.id
        # Karafka manages the offsets based on the processing state, thus we do not rely on the
        # rdkafka offset auto-storing
        kafka['enable.auto.offset.store'] = 'false'
        kafka
      end
    end
  end
end
