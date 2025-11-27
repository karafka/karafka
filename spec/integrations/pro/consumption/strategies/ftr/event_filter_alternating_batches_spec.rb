# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This spec tests a real-world event filtering scenario where batches alternate between
# having all messages filtered and having messages to process. This tests:
# 1. Correct offset advancement when alternating between filtered and processed batches
# 2. mark_as_consumed? behavior changes between all-filtered and mixed batches
# 3. Consumer is only called for batches with messages to process
# 4. Proper offset management across batch boundaries
# This scenario mimics real-world traffic where event types come in bursts.

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
  TARGET_EVENT = 'order_created'

  def apply!(messages)
    initialize_filter_state
    DT[:filter_calls] << messages.size
    batch_start = messages.first.offset

    messages.delete_if { |message| should_filter_message?(message) }

    @all_filtered = messages.empty?
    record_batch_type(batch_start)
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

  def record_batch_type(batch_start)
    if @all_filtered
      DT[:all_filtered_batches] << batch_start
    else
      DT[:processable_batches] << batch_start
    end
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

# Produce 100 messages in a pattern:
# - First 10: all filtered (user_updated)
# - Next 10: all processed (order_created)
# - Next 10: all filtered (user_updated)
# - Next 10: all processed (order_created)
# ... and so on
elements = Array.new(100) do |i|
  batch_num = i / 10
  if batch_num.even?
    { event: { name: 'user_updated', id: i } }.to_json
  else
    { event: { name: 'order_created', id: i } }.to_json
  end
end

produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  # Wait for all 10 batches to be processed (5 filtered + 5 processable)
  DT[:all_filtered_batches].size >= 5 && DT[:processable_batches].size >= 5
end

# Verify exactly half were filtered (batches 0, 2, 4, 6, 8)
assert_equal 50, DT[:filtered].size
expected_filtered = [0...10, 20...30, 40...50, 60...70, 80...90].flat_map(&:to_a)
assert_equal expected_filtered, DT[:filtered].sort

# Verify exactly half were processed (batches 1, 3, 5, 7, 9)
assert_equal 50, DT[:processed].size
expected_processed = [10...20, 30...40, 50...60, 70...80, 90...100].flat_map(&:to_a)
assert_equal expected_processed, DT[:processed].sort

# Verify we had alternating batch types
assert DT[:all_filtered_batches].size >= 5, 'Should have multiple all-filtered batches'
assert DT[:processable_batches].size >= 5, 'Should have multiple processable batches'

# Verify the all-filtered batches start at the right offsets (0, 20, 40, 60, 80)
expected_all_filtered = [0, 20, 40, 60, 80]
assert_equal expected_all_filtered, DT[:all_filtered_batches].sort

# Verify the processable batches start at the right offsets (10, 30, 50, 70, 90)
expected_processable = [10, 30, 50, 70, 90]
assert_equal expected_processable, DT[:processable_batches].sort

# Verify marked messages (should be end of each processable batch)
expected_marks = [19, 39, 59, 79, 99]
assert_equal expected_marks, DT[:marked].sort

# Verify offset advanced correctly through all batches
assert_equal 100, fetch_next_offset(DT.topic), 'Offset should advance through all batches'
