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
      attr_accessor :listeners

      def initialize
        @shutdown_mutex = Mutex.new
        @running = Set.new
      end

      # @return [Boolean] true if all the subscription groups from a given consumer group are
      #   finished
      def finished?
        @listeners.map(&:id)
      end

      # @return [Boolean] can we start shutdown on a given listener
      # @note If true, will also obtain a lock so no-one else will be closing the same time we do
      def shutdown?(listener_id)
        return true if @running.empty? && @shutdown_mutex.try_lock
        return true if @running.empty? && @shutdown_mutex.owned?

        # If it is in running it means, that even if paused, did not yet finish. If so, we should
        # not allow it to stop fully until it deregisters itself
        return false if @running.include?(listener_id)

        paused = @listeners.find { |ls| ls.id == listener_id }.paused?

        return true if paused && @shutdown_mutex.try_lock
        return true if paused && @shutdown_mutex.owned?

        false
      end

      # Unlocks the shutdown lock
      def unlock
        @shutdown_mutex.unlock if @shutdown_mutex.owned?
      end

      def start_work(listener_id)
        @running << listener_id
      end

      # Marks given listener as finished
      # @param listener_id [String]
      def finish_work(listener_id)
        @running.delete(listener_id)
      end
    end
  end
end
