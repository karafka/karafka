# frozen_string_literal: true

module Karafka
  module TimeTrackers
    # Handles Kafka topic partition pausing and resuming with exponential back-offs.
    # Since expiring and pausing can happen from both consumer and listener, this needs to be
    # thread-safe.
    #
    # @note We do not have to worry about performance implications of a mutex wrapping most of the
    #   code here, as this is not a frequently used tracker. It is active only once per batch in
    #   case of long-running-jobs and upon errors.
    class Pause < Base
      attr_reader :attempts

      # @param timeout [Integer] how long should we wait when anything went wrong (in ms)
      # @param max_timeout [Integer, nil] if exponential is on, what is the max value we can reach
      #   exponentially on which we will stay
      # @param exponential_backoff [Boolean] should we wait exponentially or with the same
      #   timeout value
      # @return [Karafka::TimeTrackers::Pause]
      # @example
      #   options = { timeout: 1000, max_timeout: 1000, exponential_backoff: false }
      #   pause = Karafka::TimeTrackers::Pause.new(**options)
      #   pause.expired? #=> true
      #   pause.paused? #=> false
      #   pause.pause
      #   pause.increment
      #   sleep(1.1)
      #   pause.paused? #=> true
      #   pause.expired? #=> true
      #   pause.attempts #=> 1
      #   pause.pause
      #   pause.increment
      #   pause.attempts #=> 2
      #   pause.paused? #=> true
      #   pause.expired? #=> false
      #   pause.resume
      #   pause.attempts #=> 2
      #   pause.paused? #=> false
      #   pause.reset
      #   pause.attempts #=> 0
      def initialize(timeout:, max_timeout:, exponential_backoff:)
        @started_at = nil
        @attempts = 0
        @timeout = timeout
        @max_timeout = max_timeout
        @exponential_backoff = exponential_backoff
        @mutex = Mutex.new
        super()
      end

      # Pauses the processing from now till the end of the interval (backoff or non-backoff)
      # and records the attempts.
      # @param timeout [Integer] timeout value in milliseconds that overwrites the default timeout
      # @note Providing this value can be useful when we explicitly want to pause for a certain
      #   period of time, outside of any regular pausing logic
      def pause(timeout = backoff_interval)
        @mutex.synchronize do
          @started_at = now
          @ends_at = @started_at + timeout
        end
      end

      # Increments the number of attempts by 1
      def increment
        @mutex.synchronize do
          @attempts += 1
        end
      end

      # Marks the pause as resumed.
      def resume
        @mutex.synchronize do
          @started_at = nil
          @ends_at = nil
        end
      end

      # Expires the pause, so it can be considered expired
      def expire
        @mutex.synchronize do
          @ends_at = nil
        end
      end

      # @return [Boolean] are we paused from processing
      def paused?
        @mutex.synchronize do
          !@started_at.nil?
        end
      end

      # @return [Boolean] did the pause expire
      def expired?
        @mutex.synchronize do
          @ends_at ? now >= @ends_at : true
        end
      end

      # Resets the pause attemptser.
      def reset
        @mutex.synchronize do
          @attempts = 0
        end
      end

      private

      # Computers the exponential backoff
      # @return [Integer] backoff in milliseconds
      def backoff_interval
        backoff_factor = @exponential_backoff ? 2**@attempts : 1

        timeout = backoff_factor * @timeout

        @max_timeout && timeout > @max_timeout ? @max_timeout : timeout
      end
    end
  end
end
