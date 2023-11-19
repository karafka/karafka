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
      # @param coordinator [Karafka::Processing::Coordinator]
      # @return [Executor] consumer executor
      def find_or_create(topic, partition, parallel_key, coordinator)
        @buffer[topic][partition][parallel_key] ||= Executor.new(
          @subscription_group.id,
          @client,
          coordinator
        )
      end

      # Revokes executors of a given topic partition, so they won't be used anymore for incoming
      # messages
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition number
      def revoke(topic, partition)
        @buffer[topic][partition].clear
      end

      # Finds all the executors available for a given topic partition
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition number
      # @return [Array<Executor>] executors in use for this topic + partition
      def find_all(topic, partition)
        @buffer[topic][partition].values
      end

      # Iterates over all available executors and yields them together with topic and partition
      # info
      # @yieldparam [Routing::Topic] karafka routing topic object
      # @yieldparam [Integer] partition number
      # @yieldparam [Executor] given executor
      def each
        @buffer.each do |_, partitions|
          partitions.each do |_, executors|
            executors.each do |_, executor|
              yield(executor)
            end
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
