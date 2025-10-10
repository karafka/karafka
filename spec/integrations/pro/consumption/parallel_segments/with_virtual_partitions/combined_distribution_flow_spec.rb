# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using both features, messages should first be distributed by parallel segments then by
# virtual partitions

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    messages.each do |message|
      vp_key = message.raw_payload.split('-').first
      DT[:processed] << [message.key, segment_id, vp_key]
      DT[segment_id] << message.raw_payload
      DT["segment-#{segment_id}-vpkey-#{vp_key}"] << message.raw_payload
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
      consumer Consumer

      virtual_partitions(
        partitioner: ->(message) { message.raw_payload.split('-').first },
        max_partitions: 3
      )
    end
  end
end

segment0_keys = []
segment1_keys = []

30.times do |i|
  key = "key-#{i}"

  segment = key.to_s.sum % 2

  if segment == 0
    segment0_keys << key
  else
    segment1_keys << key
  end
end

messages = []

segment0_keys.first(15).each do |key|
  # Use one of three VP keys
  vp_idx = segment0_keys.index(key) % 3
  vp_key = "vp#{vp_idx}"
  payload = "#{vp_key}-#{key}"

  messages << {
    topic: DT.topic,
    key: key,
    payload: payload
  }
end

# For segment 1, create messages with 3 different VP keys
segment1_keys.first(15).each do |key|
  # Use one of three VP keys
  vp_idx = segment1_keys.index(key) % 3
  vp_key = "vp#{vp_idx}"
  payload = "#{vp_key}-#{key}"

  messages << {
    topic: DT.topic,
    key: key,
    payload: payload
  }
end

Karafka::App.producer.produce_many_sync(messages)

start_karafka_and_wait_until do
  DT[:processed].size >= 30
end

# Verify each message was processed by the correct segment
by_segment = Hash.new { |h, k| h[k] = [] }
DT[:processed].each do |key, segment, _|
  by_segment[segment] << key
end

# Verify segments received the correct messages
segment0_keys.each do |key|
  next if messages.none? { |m| m[:key] == key }

  assert(
    by_segment[0].include?(key),
    "Segment 0 should process key #{key}"
  )
end

segment1_keys.each do |key|
  next if messages.none? { |m| m[:key] == key }

  assert(
    by_segment[1].include?(key),
    "Segment 1 should process key #{key}"
  )
end

# Analyze virtual partition key distribution by segment
vp_keys_by_segment = {}

DT[:processed].each do |_, segment, vp_key|
  vp_keys_by_segment[segment] ||= Set.new
  vp_keys_by_segment[segment] << vp_key
end

# Verify that multiple virtual partition keys were used in each segment
vp_keys_by_segment.each do |segment, vp_keys|
  assert(
    vp_keys.size > 1,
    "Segment #{segment} should have multiple VP keys, got: #{vp_keys.size}"
  )
end

# Verify distribution pattern: messages with same key go to same segment
key_to_segment = {}
DT[:processed].each do |key, segment, _|
  if key_to_segment[key] && key_to_segment[key] != segment
    assert(
      false,
      "Key #{key} was processed by multiple segments: #{key_to_segment[key]} and #{segment}"
    )
  end

  key_to_segment[key] = segment
end

# Calculate distribution statistics
vp_key_counts_by_segment = Hash.new { |h, k| h[k] = Hash.new(0) }
DT[:processed].each do |_, segment, vp_key|
  vp_key_counts_by_segment[segment][vp_key] += 1
end

# Check that the distribution is reasonable
vp_key_counts_by_segment.each do |segment, counts|
  # Each VP key should have approximately the same number of messages
  expected_per_key = by_segment[segment].size / counts.size
  tolerance = expected_per_key * 0.5 # Allow 50% deviation

  counts.each do |vp_key, count|
    min_expected = (expected_per_key - tolerance).floor
    max_expected = (expected_per_key + tolerance).ceil

    assert(
      count.between?(min_expected, max_expected),
      "VP key #{vp_key} in segment #{segment} has #{count} messages"
    )
  end
end
