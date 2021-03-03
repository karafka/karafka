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
        @buffer = Hash.new { |h, k| h[k] = {} }
      end

      # @param topic [String] topic name
      # @param partition [Integer] partition number
      # @param pause [TimeTrackers::Pause] pause corresponding with provided topic and partition
      # @return [Executor] consumer executor
      def fetch(
        topic,
        partition,
        pause
      )
        topic = @subscription_group.topics.find { |ktopic| ktopic.name == topic }

        topic || raise(Errors::TopicNotFound, topic)

        @buffer[topic][partition] ||= Executor.new(
          @subscription_group.id,
          @client,
          topic,
          pause
        )
      end

      # Runs the shutdown on all active executors.
      def shutdown
        @buffer.values.map(&:values).flatten.each(&:shutdown)
      end

      # Clears the executors buffer. Useful for critical errors recovery.
      def clear
        @buffer.clear
      end
    end
  end
end
