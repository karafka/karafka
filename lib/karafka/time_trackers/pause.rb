# frozen_string_literal: true

module Karafka
  module TimeTrackers
    # Handles Kafka topic partition pausing and resuming with exponential back-offs.
    class Pause < Base
      attr_reader :count

      # @param timeout [Integer] how long should we wait when anything went wrong (in ms)
      # @param max_timeout [Integer, nil] if exponential is on, what is the max value we can reach
      #   exponentially on which we will stay
      # @param exponential_backoff [Boolean] should we wait exponentially or with the same
      #   timeout value
      # @return [Karafka::TimeTrackers::Pause]
      # @example
      #   pause = Karafka::TimeTrackers::Pause.new(timeout: 1000)
      #   pause.expired? #=> true
      #   pause.paused? #=> false
      #   pause.pause
      #   sleep(1.1)
      #   pause.paused? #=> true
      #   pause.expired? #=> true
      #   pause.count #=> 1
      #   pause.pause
      #   pause.count #=> 1
      #   pause.paused? #=> true
      #   pause.expired? #=> false
      #   pause.resume
      #   pause.count #=> 2
      #   pause.paused? #=> false
      #   pause.reset
      #   pause.count #=> 0
      def initialize(timeout:, max_timeout:, exponential_backoff:)
        @started_at = nil
        @count = 0
        @timeout = timeout
        @max_timeout = max_timeout
        @exponential_backoff = exponential_backoff
        super()
      end

      # Pauses the processing from now till the end of the interval (backoff or non-backoff)
      # and records the count.
      # @param timeout [Integer] timeout value in milliseconds that overwrites the default timeout
      # @note Providing this value can be useful when we explicitly want to pause for a certain
      #   period of time, outside of any regular pausing logic
      def pause(timeout = backoff_interval)
        @started_at = now
        @ends_at = @started_at + timeout
        @count += 1
      end

      # Marks the pause as resumed.
      def resume
        @started_at = nil
        @ends_at = nil
      end

      # Expires the pause, so it can be considered expired
      def expire
        @ends_at = nil
      end

      # @return [Boolean] are we paused from processing
      def paused?
        !@started_at.nil?
      end

      # @return [Boolean] did the pause expire
      def expired?
        @ends_at ? now >= @ends_at : true
      end

      # Resets the pause counter.
      def reset
        @count = 0
      end

      private

      # Computers the exponential backoff
      # @return [Integer] backoff in milliseconds
      def backoff_interval
        backoff_factor = @exponential_backoff ? 2**@count : 1

        timeout = backoff_factor * @timeout

        @max_timeout && timeout > @max_timeout ? @max_timeout : timeout
      end
    end
  end
end
