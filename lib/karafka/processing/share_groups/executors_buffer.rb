# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      # Buffer for share-group executors of a given subscription group. It builds and caches them
      # so they are re-used across poll batches instead of being created each time.
      #
      # Parallel to {Processing::ConsumerGroups::ExecutorsBuffer}, but keyed by topic name only -
      # share consumption has no partition or parallel-group dimension.
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
          @buffer = {}
        end

        # @param topic_name [String] topic name
        # @param coordinator [Karafka::Processing::ShareGroups::Coordinator]
        # @return [Karafka::Processing::ShareGroups::Executor] found or created executor
        def find_or_create(topic_name, coordinator)
          @buffer[topic_name] ||= executor_class.new(
            @subscription_group.id,
            @client,
            coordinator
          )
        end

        # Iterates over all the cached executors
        # @yieldparam [Karafka::Processing::ShareGroups::Executor] given executor
        def each(&)
          @buffer.each_value(&)
        end

        # Clears the executors buffer. Used for critical errors recovery.
        def clear
          @buffer.clear
        end
      end
    end
  end
end
