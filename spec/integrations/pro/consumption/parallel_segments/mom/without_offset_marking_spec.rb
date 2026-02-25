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

# With manual offset management, no offsets should be automatically marked even when all messages
# are filtered

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

      # Explicitly mark messages as consumed in this consumer
      # This should be the ONLY way offsets get marked with manual offset management
      mark_as_consumed(message)
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

# Create messages that will map to specific segments
segment_messages = { 0 => [], 1 => [], 2 => [] }

# Create messages for each segment
5.times do |i|
  [0, 1, 2].each do |segment_id|
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

# Produce all messages
all_messages = segment_messages.values.flatten
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

consumed_by_segment = { 0 => [], 1 => [], 2 => [] }

DT[:consumed_messages].each do |message|
  # 3. Calculate which messages should have been processed by each segment
  segment_id = message[:segment_id]
  consumed_by_segment[segment_id] << message[:offset]

  # 4. Verify each segment only received its own messages
  key = message[:key]
  segment_id = message[:segment_id]
  expected_segment = DT[:expected_segments][key]

  assert_equal(
    expected_segment,
    segment_id,
    "Message with key #{key} was consumed by #{segment_id} instead of #{expected_segment}"
  )
end

# 5. Verify only messages that were consumed had their offsets marked
[0, 1, 2].each do |segment_id|
  # Get the highest offset consumed by this segment
  max_consumed_offset = consumed_by_segment[segment_id].max

  # Skip segments that didn't consume any messages
  next unless max_consumed_offset

  # Get the current offset for this segment
  current_offset = case segment_id
  when 0 then segment0_offset
  when 1 then segment1_offset
  when 2 then segment2_offset
  end

  # The current offset should be exactly max_consumed_offset + 1
  # This verifies only messages explicitly marked were committed
  assert_equal(
    max_consumed_offset + 1,
    current_offset,
    "Segment #{segment_id} has incorrect offset: #{max_consumed_offset + 1}, got #{current_offset}"
  )
end

# 6. Verify segment-filtered messages were NOT marked as consumed
filtered_messages = {}
ALL_SEGMENTS = [0, 1, 2].freeze

segment_messages.each do |segment_id, _messages|
  # For each segment, track which messages went to other segments (were filtered)
  other_segments = ALL_SEGMENTS - [segment_id]

  other_segments.each do |other_segment_id|
    filtered_messages[segment_id] ||= []
    filtered_messages[segment_id].concat(segment_messages[other_segment_id])
  end
end

# Track offsets that should NOT be committed by each segment
filtered_offsets = {}
filtered_messages.each do |segment_id, messages|
  # These are messages that should have been filtered by this segment
  filtered_keys = messages.map { |m| m[:key] }

  # Get offsets of messages with these keys
  all_messages_with_offsets = Karafka::Admin.read_topic(DT.topic, 0, 100)

  filtered_offsets[segment_id] = all_messages_with_offsets
    .select { |msg| filtered_keys.include?(msg.key) }
    .map(&:offset)
end

# 7. Verify that for each segment, filtered messages did not have their offsets marked
[0, 1, 2].each do |segment_id|
  # Skip if we don't have data for this segment
  next unless filtered_offsets[segment_id]&.any?

  # Get current offset for this segment
  current_offset = case segment_id
  when 0 then segment0_offset
  when 1 then segment1_offset
  when 2 then segment2_offset
  end

  # If manual offset management is working correctly, current_offset should never
  # include the offsets of messages that were filtered for this segment
  filtered_offsets[segment_id].each do |filtered_offset|
    # If the current offset is greater than this filtered offset, it would mean
    # this offset was marked despite being filtered
    next unless current_offset > filtered_offset

    consumed_offsets = consumed_by_segment[segment_id]

    # Check if this filtered offset is less than any consumed offset
    # This means it might be implicitly committed due to a higher offset being committed
    next if consumed_offsets.any? { |consumed_offset| consumed_offset > filtered_offset }

    assert(
      false,
      "Segment #{segment_id} marked offset #{filtered_offset} even though it was filtered"
    )
  end
end
