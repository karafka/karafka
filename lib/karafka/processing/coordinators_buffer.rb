# frozen_string_literal: true

module Karafka
  module Processing
    # Coordinators builder used to build coordinators per topic partition
    #
    # It provides direct pauses access for revocation
    #
    # @note This buffer operates only from the listener loop, thus we do not have to make it
    #   thread-safe.
    class CoordinatorsBuffer
      include Helpers::ConfigImporter.new(
        coordinator_class: %i[internal processing coordinator_class]
      )

      # @param topics [Karafka::Routing::Topics]
      def initialize(topics)
        @pauses_manager = Connection::PausesManager.new
        @coordinators = Hash.new { |h, k| h[k] = {} }
        @topics = topics
      end

      # @param topic_name [String] topic name
      # @param partition [Integer] partition number
      # @return [Karafka::Processing::Coordinator] found or created coordinator
      def find_or_create(topic_name, partition)
        @coordinators[topic_name][partition] ||= begin
          routing_topic = @topics.find(topic_name)

          coordinator_class.new(
            routing_topic,
            partition,
            @pauses_manager.fetch(routing_topic, partition)
          )
        end
      end

      # Resumes processing of partitions for which pause time has ended.
      # @param block we want to run for resumed topic partitions
      # @yieldparam [String] topic name
      # @yieldparam [Integer] partition number
      def resume(&block)
        @pauses_manager.resume(&block)
      end

      # @param topic_name [String] topic name
      # @param partition [Integer] partition number
      def revoke(topic_name, partition)
        return unless @coordinators[topic_name].key?(partition)

        # The fact that we delete here does not change the fact that the executor still holds the
        # reference to this coordinator. We delete it here, as we will no longer process any
        # new stuff with it and we may need a new coordinator if we regain this partition, but the
        # coordinator may still be in use
        @coordinators[topic_name].delete(partition).revoke
      end

      # Clears coordinators and re-created the pauses manager
      # This should be used only for critical errors recovery
      def reset
        @pauses_manager = Connection::PausesManager.new
        @coordinators.clear
      end
    end
  end
end
