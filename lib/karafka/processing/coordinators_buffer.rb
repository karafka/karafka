# frozen_string_literal: true

module Karafka
  module Processing
    # Buffer used to build and store coordinators
    # It provides direct pauses access for revocation
    class CoordinatorsBuffer
      def initialize
        @pauses_manager = Connection::PausesManager.new

        @coordinators = Hash.new do |h, k|
          h[k] = {}
        end
      end

      # @param topic [String] topic name
      # @param partition [Integer] partition number
      def find_or_create(topic, partition)
        pause_tracker = @pauses_manager.fetch(topic, partition)
        @coordinators[topic][partition] ||= ::Karafka::App.config.internal.coordinator.new(pause_tracker)
      end

      def pauses
        @pauses_manager
      end

      # @param topic [String] topic name
      # @param partition [Integer] partition number
      def revoke(topic, partition)
        @pauses_manager.revoke(topic, partition)

        return unless @coordinators[topic]

        @coordinators[topic].revoke

        # The fact that we delete here does not change the fact that the executor still holds the
        # reference to this coordinator. We delete it here, as we will no longer process any
        # new stuff with it and we may need a new coordinator if we regain this partition, but the
        # coordinator may still be in use
        @coordinators[topic].delete(partition)
      end

      def reset
        @pauses_manager = PausesManager.new
        @coordinators.clear
      end
    end
  end
end
