# frozen_string_literal: true

module Karafka
  module Processing
    # Buffer for executors of a given subscription group. It wraps around the concept of building
    # and caching them, so we can re-use them instead of creating new each time.
    class ExecutorsBuffer
      # @param client [Connection::Client]
      # @param subscription_group [Routing::SubscriptionGroup]
      # @return [ExecutorsBuffer]
      def initialize(client, subscription_group)
        @subscription_group = subscription_group
        @client = client
        @buffer = Hash.new { |h, k| h[k] = Hash.new  }
      end

      # @param topic []
      # @param partition []
      # @pause []
      def fetch(
        topic,
        partition,
        pause
      )
        @buffer[topic][partition] ||= Executor.new(
          @subscription_group.id,
          @client,
          @subscription_group.topics.find { |ktopic| ktopic.name == topic },
          pause
        )
      end

      def shutdown
        @buffer.values.map(&:values).flatten.each(&:shutdown)
      end

      def clear
        @buffer.clear
      end
    end
  end
end
