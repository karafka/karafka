# frozen_string_literal: true

module Karafka
  module Connection
    # This object represents a collective status of execution of group of listeners running inside
    # of one consumer group but in separate subscription groups.
    #
    # There are cases when we do not want to close a given client when others from the same
    # consumer group are running because it can cause instabilities due to early shutdown of some
    # of the clients out of same consumer group.
    #
    # We also want to make sure, we close one consumer at a time while others can continue polling.
    #
    # This prevents a scenario, where a rebalance is not acknowledged and we loose assignment
    # without having a chance to commit changes.
    class ConsumerGroupCoordinator
      # @param group_size [Integer] number of separate subscription groups in a consumer group
      def initialize(group_size)
        @shutdown_lock = Mutex.new
        @group_size = group_size
        @finished = Set.new
      end

      # @return [Boolean] true if all the subscription groups from a given consumer group are
      #   finished
      def finished?
        @finished.size == @group_size
      end

      # @return [Boolean] can we start shutdown on a given listener
      # @note If true, will also obtain a lock so no-one else will be closing the same time we do
      def shutdown?
        finished? && @shutdown_lock.try_lock
      end

      # Unlocks the shutdown lock
      def unlock
        @shutdown_lock.unlock if @shutdown_lock.owned?
      end

      # Marks given listener as finished
      # @param listener_id [String]
      def finish_work(listener_id)
        @finished << listener_id
      end
    end
  end
end
