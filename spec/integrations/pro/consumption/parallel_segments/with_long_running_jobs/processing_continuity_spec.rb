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

# Long-running jobs should maintain their parallel segment group assignment throughout execution

setup_karafka do |config|
  config.concurrency = 10
  config.max_messages = 1
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id
    message_key = messages.first.key

    # Track the initial assignment of this message
    DT[:initial_assignments] << {
      key: message_key,
      segment_id: segment_id,
      time: Time.now.to_f
    }

    # Run a long execution to exceed the max poll interval
    sleep(11)

    # Track assignment after the long-running operation to verify it's unchanged
    DT[:final_assignments] << {
      key: message_key,
      segment_id: segment_id,
      time: Time.now.to_f
    }

    # Store message content for verification
    DT[segment_id] << messages.first.raw_payload

    # Increment processed counter to help terminate the test
    DT[:processed_count] << 1
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key }
    )
    topic DT.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

# Create a smaller set of messages with fixed distribution
# 2 messages per segment = 6 total
messages_per_segment = 2
segment_messages = { 0 => [], 1 => [], 2 => [] }

# Create messages for each segment
[0, 1, 2].each do |segment_id|
  messages_per_segment.times do |i|
    # Ensure the key maps to the correct segment
    key = nil
    (0..100).each do |j|
      candidate = "key-seg#{segment_id}-#{i}-#{j}"
      if candidate.to_s.sum % 3 == segment_id
        key = candidate
        break
      end
    end

    segment_messages[segment_id] << {
      topic: DT.topic,
      key: key,
      payload: "payload-seg#{segment_id}-#{i}"
    }
  end
end

# Combine all messages
all_messages = segment_messages.values.flatten

# Record expected segment assignment for each key
expected_assignments = {}
all_messages.each do |message|
  key = message[:key]
  segment_id = key.to_s.sum % 3
  expected_assignments[key] = segment_id
end

# Produce all messages
Karafka::App.producer.produce_many_sync(all_messages)

# Start Karafka and wait until we've processed all messages
start_karafka_and_wait_until do
  # We sent 6 messages total, wait until all are processed
  DT[:processed_count].size >= 6
end

# 1. Verify initial segment assignments match expected assignments
DT[:initial_assignments].each do |assignment|
  key = assignment[:key]
  segment_id = assignment[:segment_id]
  expected_segment = expected_assignments[key]

  assert_equal(
    expected_segment,
    segment_id,
    "Initial assignment: " \
    "Key #{key} was assigned to segment #{segment_id} but should be segment #{expected_segment}"
  )
end

# 2. Verify final segment assignments match initial assignments
matched_keys = DT[:initial_assignments]
  .map { |a| a[:key] } & DT[:final_assignments]
    .map { |a| a[:key] }

matched_keys.each do |key|
  initial = DT[:initial_assignments].find { |a| a[:key] == key }
  final = DT[:final_assignments].find { |a| a[:key] == key }

  assert_equal(
    initial[:segment_id],
    final[:segment_id],
    "Assignment changed during processing: " \
    "Key #{key} moved from segment #{initial[:segment_id]} to #{final[:segment_id]}"
  )

  # Verify long running operation happened
  assert(
    final[:time] - initial[:time] >= 10,
    "Processing time was too short for key #{key}: #{final[:time] - initial[:time]} seconds"
  )
end

# 3. Verify each segment processed only its assigned messages
[0, 1, 2].each do |segment_id|
  # Skip if this segment didn't process any messages
  next unless DT[segment_id]

  # Get all keys processed by this segment
  processed_keys = DT[:final_assignments]
    .select { |a| a[:segment_id] == segment_id }
    .map { |a| a[:key] }

  processed_keys.each do |key|
    expected_segment = expected_assignments[key]

    assert_equal(
      expected_segment,
      segment_id,
      "Segment #{segment_id} processed message with key #{key} " \
      "that should be assigned to segment #{expected_segment}"
    )
  end

  # Make sure this segment processed the expected number of messages
  segment_message_count = segment_messages[segment_id].size
  processed_segment_count = DT[segment_id]&.size || 0

  assert(
    processed_segment_count <= segment_message_count,
    "Segment #{segment_id} processed #{processed_segment_count} messages, " \
    "expected at most #{segment_message_count}"
  )
end

# 4. Check that offsets were committed for each segment
segment0_group_id = "#{DT.consumer_group}-parallel-0"
segment1_group_id = "#{DT.consumer_group}-parallel-1"
segment2_group_id = "#{DT.consumer_group}-parallel-2"

segment0_offset = fetch_next_offset(DT.topic, consumer_group_id: segment0_group_id)
segment1_offset = fetch_next_offset(DT.topic, consumer_group_id: segment1_group_id)
segment2_offset = fetch_next_offset(DT.topic, consumer_group_id: segment2_group_id)

# At least one segment should have committed offsets
committed_offsets = [segment0_offset, segment1_offset, segment2_offset].count { |o| o > 0 }
assert(
  committed_offsets > 0,
  "No segments committed any offsets: #{[segment0_offset, segment1_offset, segment2_offset]}"
)
