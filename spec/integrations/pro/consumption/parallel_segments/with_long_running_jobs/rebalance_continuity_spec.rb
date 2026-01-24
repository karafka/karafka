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

# During rebalancing, long-running jobs should maintain their parallel segment assignments

setup_karafka do |config|
  config.concurrency = 5
  config.max_messages = 1
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id
    key = messages.first.key

    # Track every message received by any segment
    DT[:received] << {
      key: key,
      segment_id: segment_id,
      offset: messages.first.offset,
      time: Time.now.to_f
    }

    # Long-running task
    sleep(11)

    # Store completed message info
    DT[:completed] << {
      key: key,
      segment_id: segment_id,
      offset: messages.first.offset,
      time: Time.now.to_f
    }

    # Store processed message
    DT[segment_id] << messages.first.raw_payload

    # Mark as consumed
    mark_as_consumed(messages.first)

    # Track completion
    DT[:processed_count] << 1
  end

  def revoked
    DT[:revoked] << topic.name
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

# Create test messages that map deterministically to specific segments
segment_messages = { 0 => [], 1 => [], 2 => [] }

# Create messages for each segment with deterministic keys
[0, 1, 2].each do |segment_id|
  3.times do |i|
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
      payload: "payload-seg#{segment_id}-#{i}"
    }
  end
end

# Store expected segment assignment for each key
DT[:expected_segments] = {}
segment_messages.each do |segment_id, messages|
  messages.each do |message|
    DT[:expected_segments][message[:key]] = segment_id
  end
end

# Produce all messages
all_messages = segment_messages.values.flatten
Karafka::App.producer.produce_many_sync(all_messages)

# Thread to trigger rebalance after some processing
rebalance_thread = Thread.new do
  # Wait until some processing has started
  sleep(0.1) until DT[:received].size >= 3

  # Create a consumer to trigger rebalance
  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)

  # Poll several times to trigger rebalance
  5.times do
    consumer.poll(1000)
    sleep(0.5)
  end

  # Mark rebalance was triggered
  DT[:rebalance_triggered] = true

  # Close the consumer
  consumer.close
end

# Start Karafka and wait until processing is done
start_karafka_and_wait_until do
  DT[:processed_count].size >= 5 && DT[:rebalance_triggered]
end

# Ensure thread is done
rebalance_thread.join

# 1. Verify rebalance was triggered
assert(
  DT[:rebalance_triggered],
  'Rebalance was not triggered during the test'
)

# 2. Verify revocation was detected
assert(
  !DT[:revoked].empty?,
  'No revocations were detected during the test'
)

# 3. Group received messages by key to check segment assignment consistency
messages_by_key = {}
DT[:received].each do |record|
  key = record[:key]
  messages_by_key[key] ||= []
  messages_by_key[key] << record
end

# 4. Check if any key was received by different segments
keys_with_inconsistent_segments = []
messages_by_key.each do |key, records|
  segments = records.map { |r| r[:segment_id] }.uniq

  next if segments.size < 2

  keys_with_inconsistent_segments << {
    key: key,
    segments: segments,
    expected: DT[:expected_segments][key]
  }
end

# This is the key assertion - no key should be received by different segments
assert_equal(
  [],
  keys_with_inconsistent_segments,
  "Some keys were received by many segments after rebalancing: #{keys_with_inconsistent_segments}"
)

# 5. Verify all completions were for correctly assigned segments
DT[:completed].each do |record|
  key = record[:key]
  segment_id = record[:segment_id]
  expected_segment = DT[:expected_segments][key]

  assert_equal(
    expected_segment,
    segment_id,
    "Key #{key} was completed by segment #{segment_id} but should be segment #{expected_segment}"
  )
end

# 6. Verify offsets were committed
segment0_group_id = "#{DT.consumer_group}-parallel-0"
segment1_group_id = "#{DT.consumer_group}-parallel-1"
segment2_group_id = "#{DT.consumer_group}-parallel-2"

segment0_offset = fetch_next_offset(DT.topic, consumer_group_id: segment0_group_id)
segment1_offset = fetch_next_offset(DT.topic, consumer_group_id: segment1_group_id)
segment2_offset = fetch_next_offset(DT.topic, consumer_group_id: segment2_group_id)

committed_segments = [
  { id: 0, offset: segment0_offset },
  { id: 1, offset: segment1_offset },
  { id: 2, offset: segment2_offset }
].select { |s| s[:offset] > 0 }

assert(
  !committed_segments.empty?,
  "No segments committed any offsets: #{[segment0_offset, segment1_offset, segment2_offset]}"
)
