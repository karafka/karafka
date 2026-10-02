# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      # Builds and caches coordinators per topic partition for a share-group subscription group.
      #
      # Mirrors {Processing::ConsumerGroups::CoordinatorsBuffer}, without the pause and revocation
      # tracking (share groups do not pause and have no partition ownership).
      #
      # @note This buffer operates only from the listener loop, thus it does not have to be
      #   thread-safe.
      class CoordinatorsBuffer
        include Helpers::ConfigImporter.new(
          coordinator_class: %i[internal processing share_groups coordinator_class]
        )

        # @param topics [Karafka::Routing::Topics] topics of the subscription group
        def initialize(topics)
          @topics = topics
          @coordinators = Hash.new { |h, k| h[k] = {} }
        end

        # @param topic_name [String] topic name
        # @param partition [Integer] partition number
        # @return [Karafka::Processing::ShareGroups::Coordinator] found or created coordinator
        def find_or_create(topic_name, partition)
          @coordinators[topic_name][partition] ||= coordinator_class.new(
            @topics.find(topic_name),
            partition
          )
        end

        # Clears the coordinators. Used for critical errors recovery.
        def reset
          @coordinators.clear
        end
      end
    end
  end
end
