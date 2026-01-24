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

# Errors in reducer should be properly handled and should not crash the consumer

setup_karafka(allow_errors: true)

# Create a reducer that occasionally raises errors
class ErroringReducer
  def call(parallel_key)
    # For special "error" keys, raise an error to test error handling
    if parallel_key.to_s.include?('error')
      raise StandardError, "Simulated reducer error for key: #{parallel_key}"
    end

    # Normal behavior - map to segments 0, 1, or 2
    parallel_key.to_s.sum % 3
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    # Track all messages that reached the consumer
    messages.each do |message|
      DT[:consumed_messages] << {
        key: message.key,
        segment_id: segment_id,
        offset: message.offset
      }
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key },
      reducer: ErroringReducer.new
    )

    topic DT.topic do
      consumer Consumer
    end
  end
end

# Create three types of messages:
# 1. Messages with normal keys that map to segment 0
# 2. Messages with normal keys that map to segments 1 and 2
# 3. Messages with "error" keys that should cause reducer errors

# Normal messages for segment 0
segment0_messages = []
5.times do |i|
  key = nil
  (0..100).each do |j|
    candidate = "key-seg0-#{i}-#{j}"
    if candidate.to_s.sum % 3 == 0
      key = candidate
      break
    end
  end

  segment0_messages << {
    topic: DT.topic,
    key: key,
    payload: "payload-for-segment-0-#{i}"
  }
end

# Normal messages for segments 1 and 2
other_segments_messages = []
5.times do |i|
  # For segment 1
  key = nil
  (0..100).each do |j|
    candidate = "key-seg1-#{i}-#{j}"
    if candidate.to_s.sum % 3 == 1
      key = candidate
      break
    end
  end

  other_segments_messages << {
    topic: DT.topic,
    key: key,
    payload: "payload-for-segment-1-#{i}"
  }

  # For segment 2
  key = nil
  (0..100).each do |j|
    candidate = "key-seg2-#{i}-#{j}"
    if candidate.to_s.sum % 3 == 2
      key = candidate
      break
    end
  end

  other_segments_messages << {
    topic: DT.topic,
    key: key,
    payload: "payload-for-segment-2-#{i}"
  }
end

# Error-triggering messages
error_messages = []
5.times do |i|
  # The key includes "error" to trigger the reducer error
  key = "error-key-#{i}"

  error_messages << {
    topic: DT.topic,
    key: key,
    payload: "payload-for-error-#{i}"
  }
end

# Produce all messages
all_messages = segment0_messages + other_segments_messages + error_messages
all_messages.shuffle!
Karafka::App.producer.produce_many_sync(all_messages)

# Track which segment each key should go to normally
DT[:expected_segments] = {}
(segment0_messages + other_segments_messages).each do |message|
  key = message[:key]
  segment_id = key.to_s.sum % 3
  DT[:expected_segments][key] = segment_id
end

# Error messages should go to segment 0 when reducer errors
error_messages.each do |message|
  DT[:expected_segments][message[:key]] = 0
end

# Subscribe to errors to verify reducer errors are caught
Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:error].message.include?('Simulated reducer error')

  DT[:reducer_errors] << {
    error: event[:error].message,
    type: event[:type]
  }
end

# Start Karafka and wait until we've processed enough messages
start_karafka_and_wait_until do
  DT[:consumed_messages].size >= 15
end

# 1. Verify that reducer errors were captured
assert(
  !DT[:reducer_errors].empty?,
  'Expected reducer errors to be captured, but none were found'
)

# 2. Verify normal messages went to the correct segments
normal_keys = segment0_messages.map { |m| m[:key] } + other_segments_messages.map { |m| m[:key] }
normal_processed = DT[:consumed_messages].select { |m| normal_keys.include?(m[:key]) }

normal_processed.each do |message|
  key = message[:key]
  actual_segment = message[:segment_id]
  expected_segment = DT[:expected_segments][key]

  assert_equal(
    expected_segment,
    actual_segment,
    "Normal message with key #{key} went to #{actual_segment} instead of #{expected_segment}"
  )
end

# 3. Verify error messages were routed to segment 0
error_keys = error_messages.map { |m| m[:key] }
error_processed = DT[:consumed_messages].select { |m| error_keys.include?(m[:key]) }

error_processed.each do |message|
  actual_segment = message[:segment_id]

  assert_equal(
    0,
    actual_segment,
    "Error message with key #{message[:key]} went to segment #{actual_segment} instead of 0"
  )
end

# 4. Verify all error messages were processed (none were dropped)
processed_error_keys = error_processed.map { |m| m[:key] }
missing_error_keys = error_keys - processed_error_keys

assert(
  missing_error_keys.empty?,
  "Some error messages were not processed: #{missing_error_keys}"
)

# 5. Verify the consumer didn't crash (processed many messages)
assert(
  DT[:consumed_messages].size >= 15,
  'Not enough messages processed, consumer may have crashed'
)
