# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This spec tests a real-world event filtering scenario where we only want to process
# specific event types (e.g., "order_created") and filter out all others.
# When all messages in a batch are filtered out, the filter should:
# 1. Mark @applied as true (filtering was applied)
# 2. Set @all_filtered to true
# 3. Store the cursor at the last filtered message
# 4. Return true from mark_as_consumed? so offset advances
# This prevents consumer lag from growing when no relevant events are present.

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:processed] << message.offset
    end

    # Should not be called when all messages are filtered
    raise 'Consumer should not process when all messages are filtered'
  end
end

class EventFilter < Karafka::Pro::Processing::Filters::Base
  TARGET_EVENT = 'order_created'

  def apply!(messages)
    initialize_filter_state
    DT[:filter_calls] << messages.size

    messages.delete_if { |message| should_filter_message?(message) }

    @all_filtered = messages.empty?
    DT[:all_filtered_batches] << true if @all_filtered
  end

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

  private

  def initialize_filter_state
    @applied = false
    @cursor = nil
    @all_filtered = false
  end

  def should_filter_message?(message)
    event_name = message.payload.dig('event', 'name')
    return false if event_name == TARGET_EVENT

    @applied = true
    @cursor = message
    DT[:filtered] << message.offset
    true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(*) { EventFilter.new }
    manual_offset_management true
  end
end

# Produce 100 messages, all with different event types (none matching "order_created")
elements = Array.new(100) do |i|
  { event: { name: 'user_updated', id: i } }.to_json
end

produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:filtered].size >= 100
end

# Verify all messages were filtered
assert_equal 100, DT[:filtered].size
assert_equal (0...100).to_a, DT[:filtered].sort

# Verify consumer was never called (no messages processed)
assert_equal 0, DT[:processed].size

# Verify all batches were marked as all_filtered
assert DT[:all_filtered_batches].size >= 10, 'Should have multiple all_filtered batches'

# Verify offset advanced to the end despite all messages being filtered
assert_equal 100, fetch_next_offset(DT.topic), 'Offset should advance when all filtered'
