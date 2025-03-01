# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Messages from multiple partitions should be assigned to the same group when they match the group
# criteria

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id
    partition = messages.metadata.partition

    messages.each do |message|
      DT[:assignments] << [message.key, segment_id, partition]
      DT[segment_id] << message.raw_payload
      DT["segment-#{segment_id}-partition-#{partition}"] << message.raw_payload
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 2,
      partitioner: ->(message) { message.raw_key }
    )

    topic DT.topic do
      config(partitions: 3)
      consumer Consumer
    end
  end
end

segment0_keys = []
segment1_keys = []

100.times do |i|
  key = "key-#{i}"

  segment = key.to_s.sum % 2

  if segment == 0
    segment0_keys << key
  else
    segment1_keys << key
  end
end

all_messages = []

3.times do |partition|
  segment0_keys.first(5).each do |key|
    all_messages << {
      topic: DT.topic,
      key: key,
      payload: "partition-#{partition}-segment0-#{key}",
      partition: partition
    }
  end

  segment1_keys.first(5).each do |key|
    all_messages << {
      topic: DT.topic,
      key: key,
      payload: "partition-#{partition}-segment1-#{key}",
      partition: partition
    }
  end
end

Karafka::App.producer.produce_many_sync(all_messages)

start_karafka_and_wait_until do
  DT[:assignments].size >= 30
end

key_to_segment = {}
key_partitions = {}

DT[:assignments].each do |key, segment, partition|
  key_to_segment[key] = segment

  key_partitions[key] ||= []
  key_partitions[key] << partition unless key_partitions[key].include?(partition)
end

# Verify each key is consistently assigned to the same segment
segment0_keys.each do |key|
  next unless key_to_segment.key?(key)

  assert_equal(
    0,
    key_to_segment[key],
    "Key #{key} should be assigned to segment 0, got segment #{key_to_segment[key]}"
  )
end

segment1_keys.each do |key|
  next unless key_to_segment.key?(key)

  assert_equal(
    1,
    key_to_segment[key],
    "Key #{key} should be assigned to segment 1, got segment #{key_to_segment[key]}"
  )
end

# Verify keys from multiple partitions went to each segment
segment0_from_partitions = []
segment1_from_partitions = []

DT[:assignments].each do |_key, segment, partition|
  if segment == 0
    segment0_from_partitions << partition unless segment0_from_partitions.include?(partition)
  else
    segment1_from_partitions << partition unless segment1_from_partitions.include?(partition)
  end
end

assert(
  segment0_from_partitions.size > 1,
  "Segment 0 should receive messages from multiple partitions, got: #{segment0_from_partitions}"
)

assert(
  segment1_from_partitions.size > 1,
  "Segment 1 should receive messages from multiple partitions, got: #{segment1_from_partitions}"
)

# Verify each partition contributed messages to both segments
3.times do |partition|
  partition_segments = DT[:assignments]
                       .select { |_, _, p| p == partition }
                       .map { |_, s, _| s }
                       .uniq

  assert_equal(
    2,
    partition_segments.size,
    "Partition #{partition} should contribute to both segments, got: #{partition_segments}"
  )
end

# Verify segment counts match expectations
segment0_count = DT[0].size
segment1_count = DT[1].size

# Each segment should have 15 messages (5 keys × 3 partitions)
assert_equal 15, segment0_count, "Segment 0 should have 15 messages, got #{segment0_count}"
assert_equal 15, segment1_count, "Segment 1 should have 15 messages, got #{segment1_count}"

# Verify partition distribution within each segment
3.times do |partition|
  segment0_partition_count = DT["segment-0-partition-#{partition}"].size
  segment1_partition_count = DT["segment-1-partition-#{partition}"].size

  # Each segment should receive 5 messages from each partition
  assert_equal(
    5,
    segment0_partition_count,
    "Segment 0 should receive 5 messages from partition #{partition}"
  )

  assert_equal(
    5,
    segment1_partition_count,
    "Segment 1 should receive 5 messages from partition #{partition}"
  )
end
