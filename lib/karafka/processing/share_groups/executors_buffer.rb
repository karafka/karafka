# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      # Buffer for share-group executors of a given subscription group. It builds and caches them
      # so they are re-used across poll batches instead of being created each time.
      #
      # Mirrors {Processing::ConsumerGroups::ExecutorsBuffer}: executors are kept per topic,
      # partition and parallel key (the group a partitioner assigned the records to).
      class ExecutorsBuffer
        include Helpers::ConfigImporter.new(
          executor_class: %i[internal processing share_groups executor_class]
        )

        # @param client [Karafka::Connection::ShareGroups::Client] share client
        # @param subscription_group [Karafka::Routing::SubscriptionGroup]
        # @return [ExecutorsBuffer]
        def initialize(client, subscription_group)
          @client = client
          @subscription_group = subscription_group
          # We need two layers here to keep track of topics, partitions and processing groups
          @buffer = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }
        end

        # @param topic [String] topic name
        # @param partition [Integer] partition number
        # @param parallel_key [Integer] parallel group key
        # @param coordinator [Karafka::Processing::ShareGroups::Coordinator]
        # @return [Karafka::Processing::ShareGroups::Executor] found or created executor
        def find_or_create(topic, partition, parallel_key, coordinator)
          @buffer[topic][partition][parallel_key] ||= executor_class.new(
            @subscription_group.id,
            @client,
            coordinator
          )
        end

        # Iterates over all the cached executors
        # @yieldparam [Karafka::Processing::ShareGroups::Executor] given executor
        def each
          @buffer.each_value do |partitions|
            partitions.each_value do |executors|
              executors.each_value do |executor|
                yield(executor)
              end
            end
          end
        end

        # Clears the executors buffer. Used for critical errors recovery.
        def clear
          @buffer.clear
        end
      end
    end
  end
end
