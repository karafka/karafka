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

# When some messages are filtered out and others are processed, with the filter implementing
# `mark_as_consumed?` returning true, Karafka should mark the offset after the last processed
# message when the consumer explicitly marks it. This test verifies that:
# 1. Filtered messages are skipped
# 2. Non-filtered messages are processed
# 3. The offset is correctly stored when consumer marks as consumed
# 4. The last processed message is correctly marked

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:processed] << message.offset

      # Mark the last message as consumed
      if message.offset == messages.last.offset
        mark_as_consumed(message)
        DT[:marked] << message.offset
      end
    end
  end
end

class PartialFilter < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor

  def apply!(messages)
    # Filter messages based on payload: filter if payload starts with 'skip_'
    messages.delete_if do |message|
      should_filter = message.raw_payload.start_with?("skip_")
      DT[:filtered] << message.offset if should_filter
      should_filter
    end

    # Store the last message as cursor if any remain
    @cursor = messages.last if messages.any?
  end

  def applied?
    true
  end

  def action
    :skip
  end

  def timeout
    0
  end

  # Tell Karafka to mark the cursor position
  def mark_as_consumed?
    true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(*) { PartialFilter.new }
    manual_offset_management true
  end
end

# Produce messages - alternating between filtered and processed, ending with a processed message
elements = Array.new(50) do |i|
  if i.even?
    "skip_#{i}"
  else
    "process_#{i}"
  end
end

produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:processed].size >= 25 && DT[:filtered].size >= 25
end

# Verify that we filtered the correct messages (even offsets)
expected_filtered = (0...50).select(&:even?)
assert_equal expected_filtered, DT[:filtered].sort

# Verify that we processed the correct messages (odd offsets)
expected_processed = (0...50).select(&:odd?)
assert_equal expected_processed, DT[:processed].sort

# Verify that we marked the last processed message
assert DT[:marked].any?, "Should have marked at least one message"
assert_equal 49, DT[:marked].last, "Last marked message should be offset 49"

# Verify offset was stored correctly at the last processed message
assert_equal 50, fetch_next_offset(DT.topic), "Offset should be stored after the last message"
