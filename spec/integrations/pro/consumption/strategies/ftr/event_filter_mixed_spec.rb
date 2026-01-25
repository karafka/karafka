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

# This spec tests a real-world event filtering scenario where some messages match
# the target event type and others don't. When batches contain mixed messages:
# 1. @applied should be true when filtering occurs
# 2. @all_filtered should be false (some messages pass through)
# 3. mark_as_consumed? should return false (not all filtered)
# 4. Consumer must explicitly mark offset for processed messages
# This ensures proper offset management when processing mixed batches.

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:processed] << message.offset

      # Mark the last message in the batch
      if message.offset == messages.last.offset
        mark_as_consumed(message)
        DT[:marked] << message.offset
      end
    end
  end
end

class EventFilter < Karafka::Pro::Processing::Filters::Base
  TARGET_EVENT = "order_created"

  def apply!(messages)
    initialize_filter_state
    DT[:filter_calls] << messages.size

    messages.delete_if { |message| should_filter_message?(message) }

    @all_filtered = messages.empty?
    record_batch_type
  end

  private

  def initialize_filter_state
    @applied = false
    @cursor = nil
    @all_filtered = false
  end

  def should_filter_message?(message)
    event_name = message.payload.dig("event", "name")
    return false if event_name == TARGET_EVENT

    @applied = true
    @cursor = message
    DT[:filtered] << message.offset
    true
  end

  def record_batch_type
    DT[:all_filtered_batches] << true if @all_filtered
    DT[:mixed_batches] << true if @applied && !@all_filtered
  end

  public

  def applied?
    @applied
  end

  def action
    :skip
  end

  def timeout
    0
  end

  def mark_as_consumed?
    @all_filtered
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(*) { EventFilter.new }
    manual_offset_management true
  end
end

# Produce 100 messages, alternating between target event and other events
elements = Array.new(100) do |i|
  if i.even?
    { event: { name: "user_updated", id: i } }.to_json
  else
    { event: { name: "order_created", id: i } }.to_json
  end
end

produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:filtered].size >= 50 && DT[:processed].size >= 50
end

# Verify exactly half were filtered (even offsets)
assert_equal 50, DT[:filtered].size
expected_filtered = (0...100).select(&:even?)
assert_equal expected_filtered, DT[:filtered].sort

# Verify exactly half were processed (odd offsets)
assert_equal 50, DT[:processed].size
expected_processed = (0...100).select(&:odd?)
assert_equal expected_processed, DT[:processed].sort

# Verify we had mixed batches (not all filtered)
assert !DT[:mixed_batches].empty?, "Should have batches with mixed messages"

# Verify last message was marked
assert DT[:marked].any?, "Should have marked messages"
assert_equal 99, DT[:marked].last, "Last marked should be offset 99"

# Verify offset advanced correctly
assert_equal 100, fetch_next_offset(DT.topic), "Offset should be at the end"
