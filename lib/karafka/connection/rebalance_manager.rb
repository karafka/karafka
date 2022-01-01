# frozen_string_literal: true

module Karafka
  module Connection
    # Manager for tracking changes in the partitions assignment.
    #
    # We need tracking of those to clean up consumers that will no longer process given partitions
    # as they were taken away.
    #
    # @note Since this does not happen really often, we try to stick with same objects for the
    #   empty states most of the time, so we don't create many objects during the manager life
    #
    # @note Internally in the rebalance manager we have a notion of lost partitions. Partitions
    #   that are lost, are those that got revoked but did not get re-assigned back. We do not
    #   expose this concept outside and we normalize to have them revoked, as it is irrelevant
    #   from the rest of the code perspective as only those that are lost are truly revoked.
    class RebalanceManager
      # Empty array for internal usage not to create new objects
      EMPTY_ARRAY = [].freeze

      private_constant :EMPTY_ARRAY

      # @return [RebalanceManager]
      def initialize
        @assigned_partitions = {}
        @revoked_partitions = {}
        @lost_partitions = {}
      end

      # Resets the rebalance manager state
      # This needs to be done before each polling loop as during the polling, the state may be
      # changed
      def clear
        @assigned_partitions.clear
        @revoked_partitions.clear
        @lost_partitions.clear
      end

      # @return [Hash<String, Array<Integer>>] hash where the keys are the names of topics for
      #   which we've lost partitions and array with ids of the partitions as the value
      # @note We do not consider as lost topics and partitions that got revoked and assigned
      def revoked_partitions
        return @revoked_partitions if @revoked_partitions.empty?
        return @lost_partitions unless @lost_partitions.empty?

        @revoked_partitions.each do |topic, partitions|
          @lost_partitions[topic] = partitions - @assigned_partitions.fetch(topic, EMPTY_ARRAY)
        end

        @lost_partitions
      end

      # @return [Boolean] true if any partitions were revoked
      def revoked_partitions?
        !revoked_partitions.empty?
      end

      # Callback that kicks in inside of rdkafka, when new partitions are assigned.
      #
      # @private
      # @param _ [Rdkafka::Consumer]
      # @param partitions [Rdkafka::Consumer::TopicPartitionList]
      def on_partitions_assigned(_, partitions)
        @assigned_partitions = partitions.to_h.transform_values { |part| part.map(&:partition) }
      end

      # Callback that kicks in inside of rdkafka, when partitions are revoked.
      #
      # @private
      # @param _ [Rdkafka::Consumer]
      # @param partitions [Rdkafka::Consumer::TopicPartitionList]
      def on_partitions_revoked(_, partitions)
        @revoked_partitions = partitions.to_h.transform_values { |part| part.map(&:partition) }
      end
    end
  end
end
