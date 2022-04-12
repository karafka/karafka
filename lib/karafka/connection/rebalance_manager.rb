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
    class RebalanceManager
      # @return [Hash<String, Array<Integer>>] hash where the keys are the names of topics for
      #   which we've got new partitions assigned and array with ids of the partitions as the value
      attr_reader :assigned_partitions

      # @return [Hash<String, Array<Integer>>] hash where the keys are the names of topics for
      #   which we've lost partitions and array with ids of the partitions as the value
      attr_reader :revoked_partitions

      # @return [RebalanceManager]
      def initialize
        @assigned_partitions = {}
        @revoked_partitions = {}
      end

      # Resets the rebalance manager state
      # This needs to be done before each polling loop as during the polling, the state may be
      # changed
      def clear
        @assigned_partitions.clear
        @revoked_partitions.clear
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
