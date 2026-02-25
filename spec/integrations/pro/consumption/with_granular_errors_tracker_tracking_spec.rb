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

# Error counting should happen per error class

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 1
end

# Define different error classes for testing
E1 = Class.new(StandardError)
E2 = Class.new(StandardError)
E3 = Class.new(StandardError)

class Consumer < Karafka::BaseConsumer
  def initialized
    @error_count = 0
  end

  def consume
    # Track current error counts
    DT[:error_counts] << errors_tracker.counts.dup

    @error_count += 1

    # Raise different errors based on retry count
    case @error_count
    when 1
      raise E1
    when 2
      raise E2
    when 3
      raise E3
    when 4
      raise E1
    when 5
      raise E2
    else
      raise
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

# Produce a single message that will trigger multiple errors
produce(DT.topic, "test")

# Start Karafka and wait for multiple retries
start_karafka_and_wait_until do
  DT[:error_counts].size >= 6
end

# Verify error counts are accumulating for different error classes
last_counts = DT[:error_counts].last
assert_equal 2, last_counts[E1], "Should count E1 errors correctly"
assert_equal 2, last_counts[E2], "Should count E2 errors correctly"
assert_equal 1, last_counts[E3], "Should count E3 errors correctly"
