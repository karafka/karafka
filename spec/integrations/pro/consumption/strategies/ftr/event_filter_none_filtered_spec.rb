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

# This spec tests a real-world event filtering scenario where all messages match
# the target event type (none are filtered out). In this case:
# 1. @applied should be false (no filtering was applied)
# 2. @all_filtered should be false (messages were not filtered)
# 3. mark_as_consumed? should return false (messages need processing)
# 4. Consumer must explicitly mark offset for processed messages
# This ensures the filter behaves correctly when it's a no-op.

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
    DT[:no_filtering_batches] << true unless @applied
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

# Produce 100 messages, all with the target event type
elements = Array.new(100) do |i|
  { event: { name: "order_created", id: i } }.to_json
end

produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:processed].size >= 100
end

# Verify no messages were filtered
assert_equal 0, DT[:filtered].size

# Verify all messages were processed
assert_equal 100, DT[:processed].size
assert_equal (0...100).to_a, DT[:processed].sort

# Verify we had no filtering in any batch
assert DT[:no_filtering_batches].size >= 10, "All batches should have no filtering"

# Verify no batches were marked as all_filtered
assert_equal 0, DT[:all_filtered_batches].size

# Verify last message was marked
assert DT[:marked].any?, "Should have marked messages"
assert_equal 99, DT[:marked].last, "Last marked should be offset 99"

# Verify offset advanced correctly
assert_equal 100, fetch_next_offset(DT.topic), "Offset should be at the end"
