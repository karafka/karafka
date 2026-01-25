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

# After errors, consumers should be able to recover and continue processing in their assigned
# groups without receiving messages from other groups

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    DT[:post_trigger] = true if DT[:error_triggered] && segment_id == 0

    messages.each do |message|
      DT[:processed] << [message.key, segment_id, message.raw_payload]

      if segment_id == 0 && message.raw_payload == "error-trigger" && DT[:error_triggered].empty?
        DT[:error_triggered] << true
        raise StandardError, "Simulated error for testing recovery"
      end

      DT[segment_id] << message.raw_payload
    end
  end
end

Karafka.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "consumer.consume.error"

  DT[:errors] << event[:error]
end

draw_routes do
  consumer_group DT.consumer_group do
    # Configure 3 parallel segments for clearer testing
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key }
    )

    topic DT.topic do
      consumer Consumer
    end
  end
end

# Generate keys that will map to specific segments
segment0_keys = []
segment1_keys = []
segment2_keys = []

100.times do |i|
  key = "key-#{i}"

  segment = key.to_s.sum % 3

  case segment
  when 0
    segment0_keys << key
  when 1
    segment1_keys << key
  when 2
    segment2_keys << key
  end
end

# First batch: Include a message that will trigger an error
first_batch = []

# Make sure we definitely have a key that maps to segment 0 to trigger the error
error_key = segment0_keys.first

# Add error-triggering message for segment 0
first_batch << {
  topic: DT.topic,
  key: error_key,
  payload: "error-trigger"
}

# Add other messages for all segments
segment0_keys.first(5).each do |key|
  # Skip the error key we already added
  next if key == error_key

  first_batch << {
    topic: DT.topic,
    key: key,
    payload: "first-batch-#{key}"
  }
end

segment1_keys.first(5).each do |key|
  first_batch << {
    topic: DT.topic,
    key: key,
    payload: "first-batch-#{key}"
  }
end

segment2_keys.first(5).each do |key|
  first_batch << {
    topic: DT.topic,
    key: key,
    payload: "first-batch-#{key}"
  }
end

# Second batch: Messages to verify recovery
# Add more messages for all segments including the previously errored key
second_batch = segment0_keys.first(5).map do |key|
  {
    topic: DT.topic,
    key: key,
    payload: "second-batch-#{key}"
  }
end

segment1_keys.first(5).each do |key|
  second_batch << {
    topic: DT.topic,
    key: key,
    payload: "second-batch-#{key}"
  }
end

segment2_keys.first(5).each do |key|
  second_batch << {
    topic: DT.topic,
    key: key,
    payload: "second-batch-#{key}"
  }
end

Karafka::App.producer.produce_many_sync(first_batch)

start_karafka_and_wait_until do
  # Wait until error triggered or some processing has happened
  unless (@produced_second_batch && DT[:error_triggered].any?) || DT[:processed].size >= 10
    sleep(2) # Give time for error to be processed

    # Send second batch after error or some processing
    Karafka::App.producer.produce_many_sync(second_batch)
    @produced_second_batch = true
  end

  # Wait until both batches are processed or error occurred
  next false unless @produced_second_batch
  next false unless DT[:errors].any? || DT[:processed].size >= 25
  next false unless DT.key?(:post_trigger)
  next false unless DT[:processed].any? do |_key, segment, payload|
    segment == 0 && payload.start_with?("second-batch")
  end

  true
end

# Verify error occurred
assert DT[:errors].any?, "Error should have occurred"
assert_equal "Simulated error for testing recovery", DT[:errors].first.message

# Group processed messages by segment
by_segment = Hash.new { |h, k| h[k] = [] }
DT[:processed].each do |key, segment, _|
  by_segment[segment] << key
end

# Verify each segment only processed its assigned keys
segment0_processed = by_segment[0]
segment1_processed = by_segment[1]
segment2_processed = by_segment[2]

# Verify no segment processed keys meant for other segments
segment0_processed.each do |key|
  assert(
    segment0_keys.include?(key),
    "Segment 0 processed key #{key} that should have gone to another segment"
  )
end

segment1_processed.each do |key|
  assert(
    segment1_keys.include?(key),
    "Segment 1 processed key #{key} that should have gone to another segment"
  )
end

segment2_processed.each do |key|
  assert(
    segment2_keys.include?(key),
    "Segment 2 processed key #{key} that should have gone to another segment"
  )
end

# Verify segment 0 recovered after error and processed its second batch
segment0_second_batch = DT[:processed].select do |_key, segment, payload|
  segment == 0 && payload.start_with?("second-batch")
end

assert(
  !segment0_second_batch.empty?,
  "Segment 0 should process messages after recovery"
)

# Verify other segments processed their messages from both batches
segment1_first_batch = DT[:processed].select do |_key, segment, payload|
  segment == 1 && payload.start_with?("first-batch")
end

segment1_second_batch = DT[:processed].select do |_key, segment, payload|
  segment == 1 && payload.start_with?("second-batch")
end

segment2_first_batch = DT[:processed].select do |_key, segment, payload|
  segment == 2 && payload.start_with?("first-batch")
end

segment2_second_batch = DT[:processed].select do |_key, segment, payload|
  segment == 2 && payload.start_with?("second-batch")
end

assert !segment1_first_batch.empty?, "Segment 1 should process first batch"
assert !segment1_second_batch.empty?, "Segment 1 should process second batch"
assert !segment2_first_batch.empty?, "Segment 2 should process first batch"
assert !segment2_second_batch.empty?, "Segment 2 should process second batch"
