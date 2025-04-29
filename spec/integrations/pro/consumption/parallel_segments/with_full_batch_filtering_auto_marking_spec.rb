# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# With automatic offset management, offsets should be marked even when all messages are filtered

setup_karafka do |config|
  config.concurrency = 5
  config.max_messages = 1
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

    sleep(1)
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
      # No manual_offset_management - we want automatic
    end
  end
end

# Create messages that will ONLY go to segment 0
# Segments 1 and 2 will have all messages filtered
segment0_messages = []

# Create 10 messages that all map to segment 0
10.times do |i|
  # Create a key that deterministically maps to segment 0
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

# Produce all messages
Karafka::App.producer.produce_many_sync(segment0_messages)

# Start Karafka and wait until we've processed some messages
start_karafka_and_wait_until do
  DT[:consumed_messages].size >= segment0_messages.size
end

# Sleep a bit to ensure offset commits have time to complete
sleep(2)

# 1. Get the consumer group IDs for all segments
segment0_group_id = "#{DT.consumer_group}-parallel-0"
segment1_group_id = "#{DT.consumer_group}-parallel-1"
segment2_group_id = "#{DT.consumer_group}-parallel-2"

# 2. Get the current offsets for each segment
segment0_offset = fetch_next_offset(DT.topic, consumer_group_id: segment0_group_id)
segment1_offset = fetch_next_offset(DT.topic, consumer_group_id: segment1_group_id)
segment2_offset = fetch_next_offset(DT.topic, consumer_group_id: segment2_group_id)

# 3. Verify segment 0 received and processed messages
consumed_by_segment0 = DT[:consumed_messages].select { |m| m[:segment_id] == 0 }
assert(
  !consumed_by_segment0.empty?,
  'Segment 0 should have received and processed messages'
)

# 4. Verify segments 1 and 2 didn't receive any messages (all filtered)
consumed_by_segment1 = DT[:consumed_messages].select { |m| m[:segment_id] == 1 }
consumed_by_segment2 = DT[:consumed_messages].select { |m| m[:segment_id] == 2 }

assert_equal(
  0,
  consumed_by_segment1.size,
  "Segment 1 should not have received any messages, got: #{consumed_by_segment1.size}"
)

assert_equal(
  0,
  consumed_by_segment2.size,
  "Segment 2 should not have received any messages, got: #{consumed_by_segment2.size}"
)

# 5. Verify segment 0 marked offsets (it processed messages)
assert(
  segment0_offset > 0,
  "Segment 0 should have marked offsets, but got: #{segment0_offset}"
)

# 6. Verify segments 1 and 2 also marked offsets despite receiving no messages
# This is key - with automatic offset management, filtered messages should still be marked
assert(
  segment1_offset > 0,
  "Segment 1 should have marked offsets despite filtering, but got: #{segment1_offset}"
)

assert(
  segment2_offset > 0,
  "Segment 2 should have marked offsets despite filtering, but got: #{segment2_offset}"
)

# 7. Get the highest offset from the topic to verify they marked up to it
highest_offset = Karafka::Admin.read_watermark_offsets(DT.topic, 0).last

# 8. Verify segments 1 and 2 marked approximately up to the highest offset
# They may not match exactly, but should be close
assert(
  segment1_offset >= highest_offset - 3,
  "Segment 1 offset (#{segment1_offset}) should be close to highest offset (#{highest_offset})"
)

assert(
  segment2_offset >= highest_offset - 3,
  "Segment 2 offset (#{segment2_offset}) should be close to highest offset (#{highest_offset})"
)

# 9. Check lag for all segments - should be minimal
offsets_with_lags = Karafka::Admin.read_lags_with_offsets

# Each segment should have minimal lag (0 or 1)
[segment0_group_id, segment1_group_id, segment2_group_id].each do |group_id|
  lag_info = offsets_with_lags.dig(group_id, DT.topic, 0)

  next unless lag_info

  lag = lag_info[:lag]
  assert(
    lag <= 1,
    "Consumer group #{group_id} should have minimal lag, but has: #{lag}"
  )
end
