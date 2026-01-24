# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
