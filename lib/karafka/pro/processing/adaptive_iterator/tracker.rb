# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module AdaptiveIterator
        # Tracker is responsible for monitoring the processing of messages within the poll
        # interval limitation.
        # It ensures that the consumer does not exceed the maximum poll interval by tracking the
        # processing cost and determining when to halt further processing (if needed).
        class Tracker
          include Karafka::Core::Helpers::Time

          # Initializes a new Tracker instance.
          #
          # @param safety_margin [Float] The safety margin percentage (0-100) to leave as a buffer.
          # @param last_polled_at [Float] The timestamp of the last polling in milliseconds.
          # @param max_poll_interval_ms [Integer] The maximum poll interval time in milliseconds.
          def initialize(
            safety_margin,
            last_polled_at,
            max_poll_interval_ms
          )
            @safety_margin = safety_margin / 100.0 # Convert percentage to decimal
            @last_polled_at = last_polled_at
            @max_processing_cost = 0
            @max_poll_interval_ms = max_poll_interval_ms
          end

          # Tracks the processing time of a block and updates the maximum processing cost.
          #
          # @yield Executes the block, measuring the time taken for processing.
          def track
            before = monotonic_now

            yield

            time_taken = monotonic_now - before

            return unless time_taken > @max_processing_cost

            @max_processing_cost = time_taken
          end

          # Determines if there is enough time left to process more messages without exceeding the
          # maximum poll interval, considering both the safety margin and adaptive margin.
          #
          # @return [Boolean] Returns true if it is time to stop processing. False otherwise.
          def enough?
            elapsed_time_ms = monotonic_now - @last_polled_at
            remaining_time_ms = @max_poll_interval_ms - elapsed_time_ms

            safety_margin_ms = @max_poll_interval_ms * @safety_margin

            return true if remaining_time_ms <= safety_margin_ms
            return true if remaining_time_ms - @max_processing_cost <= safety_margin_ms

            false
          end
        end
      end
    end
  end
end
