# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Even with uneven distribution, each consumer should only process messages for its assigned group

setup_karafka do |config|
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      segment_id = topic.consumer_group.segment_id
      DT[segment_id] << message.raw_payload
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    # Using 3 segments to make the uneven distribution more apparent
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key }
    )

    topic DT.topic do
      consumer Consumer
    end
  end
end

# Create a custom partitioning scheme that heavily favors one group
# Group 0 will get ~70% of messages
# Group 1 will get ~20% of messages
# Group 2 will get ~10% of messages

# Generate payloads with keys that will distribute unevenly
group0_keys_payloads = []
group1_keys_payloads = []
group2_keys_payloads = []

# Keys that will always go to group 0 (keys with mod 3 = 0)
1000.times do |i|
  key = "group0-#{i}"
  # Ensure this key always maps to group 0
  next unless (key.to_s.sum % 3).zero?

  payload = "payload-group0-#{i}"
  group0_keys_payloads << [key, payload]
end

# Keys that will always go to group 1 (keys with mod 3 = 1)
100.times do |i|
  key = "group1-#{i}"
  # Ensure this key always maps to group 1
  next unless (key.to_s.sum % 3) == 1

  payload = "payload-group1-#{i}"
  group1_keys_payloads << [key, payload]
end

# Keys that will always go to group 2 (keys with mod 3 = 2)
100.times do |i|
  key = "group2-#{i}"
  # Ensure this key always maps to group 2
  next unless (key.to_s.sum % 3) == 2

  payload = "payload-group2-#{i}"
  group2_keys_payloads << [key, payload]
end

# Take the first X items from each group to control distribution
group0_keys_payloads = group0_keys_payloads.first(70)
group1_keys_payloads = group1_keys_payloads.first(20)
group2_keys_payloads = group2_keys_payloads.first(10)

# Create messages for each group
messages = []
group0_payloads = []
group0_keys_payloads.each do |key, payload|
  messages << { topic: DT.topic, key: key, payload: payload }
  group0_payloads << payload
end

group1_payloads = []
group1_keys_payloads.each do |key, payload|
  messages << { topic: DT.topic, key: key, payload: payload }
  group1_payloads << payload
end

group2_payloads = []
group2_keys_payloads.each do |key, payload|
  messages << { topic: DT.topic, key: key, payload: payload }
  group2_payloads << payload
end

# Shuffle messages to simulate random arrival order
messages.shuffle!

# Produce all messages
Karafka::App.producer.produce_many_sync(messages)

start_karafka_and_wait_until do
  DT[0].size >= 70 && DT[1].size >= 20 && DT[2].size >= 10
end

# Verify each group received exactly its assigned messages
assert_equal group0_payloads.sort, DT[0].sort
assert_equal group1_payloads.sort, DT[1].sort
assert_equal group2_payloads.sort, DT[2].sort

# Verify distribution is uneven as expected
assert DT[0].size > DT[1].size
assert DT[1].size > DT[2].size

# Verify total message count
assert_equal 100, DT[0].size + DT[1].size + DT[2].size

# Get the consumer group IDs for all segments to verify they've processed some data
segment0_group_id = "#{DT.consumer_group}-parallel-0"
segment1_group_id = "#{DT.consumer_group}-parallel-1"
segment2_group_id = "#{DT.consumer_group}-parallel-2"

# Verify offsets for all segments
segment0_offset = fetch_next_offset(DT.topic, consumer_group_id: segment0_group_id)
segment1_offset = fetch_next_offset(DT.topic, consumer_group_id: segment1_group_id)
segment2_offset = fetch_next_offset(DT.topic, consumer_group_id: segment2_group_id)

# All segments should have processed some messages
assert segment0_offset > 0
assert segment1_offset > 0
assert segment2_offset > 0
