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
        # We need two layers here to keep track of topics, partitions and processing groups
        @buffer = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }
      end

      # Finds or creates an executor based on the provided details
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition number
      # @param parallel_key [String] parallel group key
      # @return [Executor] consumer executor
      def find_or_create(topic, partition, parallel_key)
        ktopic = find_topic(topic)

        @buffer[ktopic][partition][parallel_key] ||= Executor.new(
          @subscription_group.id,
          @client,
          ktopic
        )
      end

      # Revokes executors of a given topic partition, so they won't be used anymore for incoming
      # messages
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition number
      def revoke(topic, partition)
        ktopic = find_topic(topic)

        @buffer[ktopic][partition].clear
      end

      # Finds all the executors available for a given topic partition
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition number
      # @return [Array<Executor>] executors in use for this topic + partition
      def find_all(topic, partition)
        ktopic = find_topic(topic)

        @buffer[ktopic][partition].values
      end

      # Iterates over all available executors and yields them together with topic and partition
      # info
      # @yieldparam [Routing::Topic] karafka routing topic object
      # @yieldparam [Integer] partition number
      # @yieldparam [Executor] given executor
      def each
        @buffer.each do |ktopic, partitions|
          partitions.each do |partition, executors|
            executors.each do |_parallel_key, executor|
              # We skip the parallel key here as it does not serve any value when iterating
              yield(ktopic, partition, executor)
            end
          end
        end
      end

      # Clears the executors buffer. Useful for critical errors recovery.
      def clear
        @buffer.clear
      end

      private

      # Finds topic based on its name
      #
      # @param topic [String] topic we're looking for
      # @return [Karafka::Routing::Topic] topic we're interested in
      def find_topic(topic)
        @subscription_group.topics.find(topic) || raise(Errors::TopicNotFoundError, topic)
      end
    end
  end
end
