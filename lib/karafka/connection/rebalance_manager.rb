# frozen_string_literal: true

module Karafka
  module Connection
    # Manager for tracking changes in the partitions assignment after the assignment is done and
    # for ensuring, that proper buffer related operations that may be impacted by the rebalance
    # state are applied.
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
    #
    # @note For cooperative-sticky `#assigned_partitions` holds only the recently assigned
    #   partitions, not all the partitions that are owned
    #
    # @note We have to have the `subscription_group` reference because we have a global pipeline
    #   for notifications and we need to make sure we track changes only for things that are of
    #   relevance to our subscription group
    class RebalanceManager
      # Empty array for internal usage not to create new objects
      EMPTY_ARRAY = [].freeze

      attr_reader :assigned_partitions, :revoked_partitions

      private_constant :EMPTY_ARRAY

      # @param subscription_group_id [String] subscription group id
      # @param buffer [Karafka::Connection::RawMessagesBuffer]
      # @return [RebalanceManager]
      def initialize(subscription_group_id, buffer)
        @assigned_partitions = {}
        @revoked_partitions = {}
        @changed = false
        @active = false
        @subscription_group_id = subscription_group_id
        @buffer = buffer

        # Connects itself to the instrumentation pipeline so rebalances can be tracked
        ::Karafka.monitor.subscribe(self)
      end

      # Resets the rebalance manager state
      # This needs to be done before each polling loop as during the polling, the state may be
      # changed
      def clear
        @assigned_partitions.clear
        @revoked_partitions.clear
        @changed = false
      end

      # @return [Boolean] indicates a state change in the partitions assignment
      def changed?
        @changed
      end

      # @return [Boolean] true if there was at least one rebalance
      # @note This method is needed to make sure that when using cooperative-sticky, we do not
      #   close until first rebalance. Otherwise librdkafka may crash.
      # @see https://github.com/confluentinc/librdkafka/issues/4312
      def active?
        @active
      end

      # Callback that kicks in inside of rdkafka, when new partitions were assigned.
      #
      # @private
      # @param event [Karafka::Core::Monitoring::Event]
      def on_rebalance_partitions_assigned(event)
        # Apply changes only for our subscription group
        return unless event[:subscription_group_id] == @subscription_group_id

        @active = true
        @assigned_partitions = event[:tpl].to_h.transform_values { |part| part.map(&:partition) }
        @changed = true
      end

      # Callback that kicks in inside of rdkafka, when partitions were revoked.
      #
      # @private
      # @param event [Karafka::Core::Monitoring::Event]
      def on_rebalance_partitions_revoked(event)
        # Apply changes only for our subscription group
        return unless event[:subscription_group_id] == @subscription_group_id

        @active = true
        @revoked_partitions = event[:tpl].to_h.transform_values { |part| part.map(&:partition) }
        @changed = true

        remove_revoked_and_duplicated_messages
      end

      private

      # We may have a case where in the middle of data polling, we've lost a partition.
      # In a case like this we should remove all the pre-buffered messages from list partitions as
      # we are no longer responsible in a given process for processing those messages and they
      # should have been picked up by a different process.
      def remove_revoked_and_duplicated_messages
        @revoked_partitions.each do |topic, partitions|
          partitions.each do |partition|
            @buffer.delete(topic, partition)
          end
        end

        @buffer.uniq!
      end
    end
  end
end
