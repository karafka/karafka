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

# With manual offset management and all messages filtered in one segment, no offsets should be
# marked in this segment

setup_karafka do |config|
  config.concurrency = 5
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

      # We deliberately DO NOT mark any messages as consumed
      # This will help verify that nothing is automatically marked
    end
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
      manual_offset_management true
    end
  end
end

# Create messages, but only for segments 0 and 1
# Segment 2 will receive NO messages due to partitioning
segment_messages = { 0 => [], 1 => [], 2 => [] }

# Create messages for specific segments
10.times do |i|
  [0, 1].each do |segment_id|
    # Create a key that maps to this segment
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
      payload: "payload-for-segment-#{segment_id}-#{i}"
    }
  end
end

# Store expected segment assignments
DT[:expected_segments] = {}
segment_messages.each do |segment_id, messages|
  messages.each do |message|
    DT[:expected_segments][message[:key]] = segment_id
  end
end

# Produce all messages (only for segments 0 and 1)
all_messages = segment_messages[0] + segment_messages[1]
Karafka::App.producer.produce_many_sync(all_messages)

# Start Karafka and wait until we have processed some messages
start_karafka_and_wait_until do
  DT[:consumed_messages].size >= 10
end

# 1. Get the consumer group IDs for all segments
segment0_group_id = "#{DT.consumer_group}-parallel-0"
segment1_group_id = "#{DT.consumer_group}-parallel-1"
segment2_group_id = "#{DT.consumer_group}-parallel-2"

# 2. Get the current offsets for each segment
segment0_offset = fetch_next_offset(DT.topic, consumer_group_id: segment0_group_id)
segment1_offset = fetch_next_offset(DT.topic, consumer_group_id: segment1_group_id)
segment2_offset = fetch_next_offset(DT.topic, consumer_group_id: segment2_group_id)

# 3. Verify each segment processed the right messages
consumed_by_segment = { 0 => [], 1 => [], 2 => [] }
DT[:consumed_messages].each do |message|
  segment_id = message[:segment_id]
  consumed_by_segment[segment_id] << message[:offset]

  key = message[:key]
  expected_segment = DT[:expected_segments][key]

  assert_equal(
    expected_segment,
    segment_id,
    "Message with key #{key} was consumed by #{segment_id} instead of segment #{expected_segment}"
  )
end

# 4. Verify no messages were received for segment 2
assert_equal(
  0,
  consumed_by_segment[2].size,
  "Segment 2 should not have received any messages, but got: #{consumed_by_segment[2].size}"
)

# 5. Verify segments 0 and 1 received messages
assert(
  !consumed_by_segment[0].empty?,
  'Segment 0 should have received messages'
)

assert(
  !consumed_by_segment[1].empty?,
  'Segment 1 should have received messages'
)

# 6. Verify NO offsets were marked for any segment (since we didn't mark anything)
[0, 1, 2].each do |segment_id|
  # Get current offset for this segment
  current_offset = case segment_id
                   when 0 then segment0_offset
                   when 1 then segment1_offset
                   when 2 then segment2_offset
                   end

  # With manual offset management and no explicit marking, offset should be -1001 (initial)
  # or 0 (initial in some Kafka versions) since nothing was marked
  assert(
    current_offset <= 0,
    "Segment #{segment_id} has offset #{current_offset}, expected <= 0 (no marking)"
  )
end

# 7. Verify specifically that segment 2 has no committed offset
# This is the key test - segment 2 received only filtered messages and should have no commits
assert_equal(
  0,
  segment2_offset,
  "Segment 2 has committed offset #{segment2_offset}, expected 0"
)

# 8. Double-check using lag calculation
offsets_with_lags = Karafka::Admin.read_lags_with_offsets

# For each segment, verify lag is equal to total number of messages (nothing consumed)
[0, 1, 2].each do |segment_id|
  segment_group_id = "#{DT.consumer_group}-parallel-#{segment_id}"

  # Get lag for all partitions for this segment
  total_lag = 0
  partition_info = offsets_with_lags.dig(segment_group_id, DT.topic, 0)
  total_lag += partition_info[:lag]

  assert_equal(total_lag, - 1)
end
