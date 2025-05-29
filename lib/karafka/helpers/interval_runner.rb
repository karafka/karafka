# frozen_string_literal: true

module Karafka
  module Helpers
    # Object responsible for running given code with a given interval. It won't run given code
    # more often than with a given interval.
    #
    # This allows us to execute certain code only once in a while.
    #
    # This can be used when we have code that could be invoked often due to it being in loops
    # or other places but would only slow things down if would run with each tick.
    class IntervalRunner
      include Karafka::Core::Helpers::Time

      # @param interval [Integer] interval in ms for running the provided code. Defaults to the
      #   `internal.tick_interval` value
      # @param block [Proc] block of code we want to run once in a while
      def initialize(interval: ::Karafka::App.config.internal.tick_interval, &block)
        @block = block
        @interval = interval
        @last_called_at = monotonic_now - @interval
      end

      # Runs the requested code if it was not executed previously recently
      def call
        return if monotonic_now - @last_called_at < @interval

        @last_called_at = monotonic_now

        @block.call
      end

      # Runs the requested code bypassing any time frequencies
      # Useful when we have certain actions that usually need to run periodically but in some
      # cases need to run asap
      def call!
        @last_called_at = monotonic_now
        @block.call
      end

      # Resets the runner, so next `#call` will run the underlying code
      def reset
        @last_called_at = monotonic_now - @interval
      end
    end
  end
end
