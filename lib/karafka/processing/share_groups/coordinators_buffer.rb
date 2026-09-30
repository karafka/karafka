# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      # Builds and caches coordinators per topic for a share-group subscription group.
      #
      # A share poll batch is coordinated per topic (partition is not meaningful at the batch
      # level - see {Coordinator}), so unlike the consumer-group buffer this is keyed by topic name
      # only and has no pause/revocation tracking.
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
          @coordinators = {}
        end

        # @param topic_name [String] topic name
        # @return [Karafka::Processing::ShareGroups::Coordinator] found or created coordinator
        def find_or_create(topic_name)
          @coordinators[topic_name] ||= coordinator_class.new(@topics.find(topic_name))
        end

        # Clears the coordinators. Used for critical errors recovery.
        def reset
          @coordinators.clear
        end
      end
    end
  end
end
