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
        ktopic = @subscription_group.topics.find(topic)

        ktopic || raise(Errors::TopicNotFoundError, topic)

        @buffer[ktopic][partition] ||= Executor.new(
          @subscription_group.id,
          @client,
          ktopic,
          pause
        )
      end

      # Iterates over all available executors and yields them together with topic and partition
      # info
      # @yieldparam [Routing::Topic] karafka routing topic object
      # @yieldparam [Integer] partition number
      # @yieldparam [Executor] given executor
      def each
        @buffer.each do |ktopic, partitions|
          partitions.each do |partition, executor|
            yield(ktopic, partition, executor)
          end
        end
      end

      # Clears the executors buffer. Useful for critical errors recovery.
      def clear
        @buffer.clear
      end
    end
  end
end
