# frozen_string_literal: true

module Karafka
  module Connection
    # Tracks consecutive batch_poll calls that produced only recoverable errors with no
    # messages. After max_retries such batches, raises the last error so the listener
    # can reset the consumer and wait out the configured backoff - without this the
    # consumer can get permanently stuck on a persistent non-fatal error with no way out.
    class ConsecutiveErrorsTracker
      # @param max_retries [Integer]
      def initialize(max_retries)
        @max_retries = max_retries
        @count = 0
      end

      # Records the outcome of one batch_poll call. If there was a recoverable error and
      # no messages were received (no progress), increments the counter and raises once
      # the threshold is reached. Resets when progress is made or no error occurred.
      #
      # @param error [Rdkafka::RdkafkaError, nil] last recoverable error seen, or nil
      # @param progress [Boolean] true if the buffer contained at least one message
      def call(error, progress:)
        if error && !progress
          @count += 1
          raise error if @count >= @max_retries
        else
          @count = 0
        end
      end

      # Resets the counter. Call when the consumer is reset so the new consumer starts fresh.
      def reset
        @count = 0
      end
    end
  end
end
