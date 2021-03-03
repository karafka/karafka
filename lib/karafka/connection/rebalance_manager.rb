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
      # @return [RebalanceManager]
      def initialize
        @assigned = {}
        @revoked = {}
      end

      # @return [Hash<String, Array<Integer>>] hash where the keys are the names of topics for
      #   which we've got new partitions assigned and array with ids of the partitions as the value
      # @note Once assigned partitions are fetched, the state will be reset since the callbacks
      #   for new assigned partitions are set only during a state change
      def assigned_partitions
        return @assigned if @assigned.empty?

        result = @assigned.dup
        @assigned.clear
        result
      end

      # @return [Hash<String, Array<Integer>>] hash where the keys are the names of topics for
      #   which we've lost partitions and array with ids of the partitions as the value
      # @note Once revoked partitions are fetched, the state will be reset since the callbacks
      #   for new revoked partitions are set only during a state change
      def revoked_partitions
        return @revoked if @revoked.empty?

        result = @revoked.dup
        @revoked.clear
        result
      end

      # Callback that kicks in inside of rdkafka, when new partitions are assigned.
      #
      # @private
      # @param _ [Rdkafka::Consumer]
      # @param partitions [Rdkafka::Consumer::TopicPartitionList]
      def on_partitions_assigned(_, partitions)
        @assigned = partitions.to_h.transform_values { |part| part.map(&:partition) }
      end

      # Callback that kicks in inside of rdkafka, when partitions are revoked.
      #
      # @private
      # @param _ [Rdkafka::Consumer]
      # @param partitions [Rdkafka::Consumer::TopicPartitionList]
      def on_partitions_revoked(_, partitions)
        @revoked = partitions.to_h.transform_values { |part| part.map(&:partition) }
      end
    end
  end
end
