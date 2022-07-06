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
      def initialize
        @pauses_manager = Connection::PausesManager.new
        @coordinator_class = ::Karafka::App.config.internal.processing.coordinator_class
        @coordinators = Hash.new { |h, k| h[k] = {} }
      end

      # @param topic [String] topic name
      # @param partition [Integer] partition number
      def find_or_create(topic, partition)
        @coordinators[topic][partition] ||= @coordinator_class.new(
          @pauses_manager.fetch(topic, partition)
        )
      end

      # Resumes processing of partitions for which pause time has ended.
      # @param block we want to run for resumed topic partitions
      # @yieldparam [String] topic name
      # @yieldparam [Integer] partition number
      def resume(&block)
        @pauses_manager.resume(&block)
      end

      # @param topic [String] topic name
      # @param partition [Integer] partition number
      def revoke(topic, partition)
        return unless @coordinators[topic].key?(partition)

        # The fact that we delete here does not change the fact that the executor still holds the
        # reference to this coordinator. We delete it here, as we will no longer process any
        # new stuff with it and we may need a new coordinator if we regain this partition, but the
        # coordinator may still be in use
        @coordinators[topic].delete(partition).revoke
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
