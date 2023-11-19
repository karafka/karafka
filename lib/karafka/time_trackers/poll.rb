# frozen_string_literal: true

module Karafka
  module TimeTrackers
    # Object used to keep track of time we've used running certain operations. Polling is
    # running in a single thread, thus we do not have to worry about this being thread-safe.
    #
    # @example Keep track of sleeping and stop after 3 seconds of 0.1 sleep intervals
    #   time_poll = Poll.new(3000)
    #   time_poll.start
    #
    #   until time_poll.exceeded?
    #     time_poll.start
    #     puts "I have #{time_poll.remaining.to_i}ms remaining to sleep..."
    #     sleep(0.1)
    #     time_poll.checkpoint
    #   end
    class Poll < Base
      attr_reader :remaining, :attempts

      # @param total_time [Integer] amount of milliseconds before we exceed the given time limit
      # @return [TimeTracker] time poll instance
      def initialize(total_time)
        @remaining = total_time
        @attempts = 0
        super()
      end

      # @return [Boolean] did we exceed the time limit
      def exceeded?
        @remaining <= 0
      end

      # Starts time tracking.
      def start
        @attempts += 1
        @started_at = monotonic_now
      end

      # Stops time tracking of a given piece of code and updates the remaining time.
      def checkpoint
        @remaining -= (monotonic_now - @started_at)
      end

      # @return [Boolean] If anything went wrong, can we retry after a backoff period or not
      #   (do we have enough time)
      def retryable?
        remaining > backoff_interval
      end

      # Sleeps for amount of time matching attempt, so we sleep more with each attempt in case of
      #   a retry.
      def backoff
        # backoff should not be included in the remaining time computation, otherwise it runs
        # shortly, never back-offing beyond a small number because of the sleep
        @remaining += backoff_interval
        # Sleep requires seconds not ms
        sleep(backoff_interval / 1_000.0)
      end

      private

      # @return [Integer] milliseconds of the backoff time
      def backoff_interval
        100 * attempts
      end
    end
  end
end
