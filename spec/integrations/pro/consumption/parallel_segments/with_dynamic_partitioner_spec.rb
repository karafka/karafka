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

# Dynamic partitioners should be able to change distribution rules mid-flow and consumers should
# adapt

setup_karafka do |config|
  config.concurrency = 10
end

# Create a dynamic partitioner that changes based on a shared flag
class DynamicPartitioner
  def initialize
    # Start with key-based partitioning
    @mutex = Mutex.new
  end

  def call(message)
    # Use different partitioning keys based on the current mode
    if DT[:use_payload_based] == true
      # Use the message payload as the partitioning key
      DT[:partitioning_used] << [:payload_based, message.raw_payload]

      message.raw_payload
    else
      # Use the message key directly
      DT[:partitioning_used] << [:key_based, message.key]

      message.key
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    messages.each do |message|
      DT[:processed] << [
        segment_id,
        message.key,
        message.raw_payload
      ]

      DT[segment_id] << message.raw_payload
    end
  end
end

# Create a dynamic partitioner instance to use in routing
dynamic_partitioner = DynamicPartitioner.new

# Set the number of segments for testing
segment_count = 3

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: segment_count,
      partitioner: dynamic_partitioner
    )

    topic DT.topic do
      consumer Consumer
    end
  end
end

# Set initial partitioning mode
DT[:use_payload_based] = false

# Create first batch with keys that will distribute predictably
first_batch = []
15.times do |i|
  # Create keys that will map to each segment evenly
  key = "key-batch1-#{i}"

  # Create distinct payloads to ensure they distribute differently
  payload = "payload-batch1-#{i}"

  first_batch << {
    topic: DT.topic,
    key: key,
    payload: payload
  }
end

# Pre-calculate expected segment assignment for each key
expected_key_segments = {}
first_batch.each do |message|
  key = message[:key]
  # Use the same formula as the reducer in parallel segments
  expected_key_segments[key] = key.to_s.sum % segment_count
end

# Create second batch with the same keys but different payloads
second_batch = []
15.times do |i|
  # Use the same keys as first batch
  key = "key-batch2-#{i}"

  # Create fewer unique payloads to ensure grouping
  # This will result in different distribution from key-based
  payload = "payload-batch2-#{i % 3}"

  second_batch << {
    topic: DT.topic,
    key: key,
    payload: payload
  }
end

# Pre-calculate expected segment assignment for each payload
expected_payload_segments = {}
second_batch.each do |message|
  payload = message[:payload]
  unless expected_payload_segments.key?(payload)
    # Use the same formula as the reducer in parallel segments
    expected_payload_segments[payload] = payload.to_s.sum % segment_count
  end
end

# Produce first batch with key-based partitioning
Karafka::App.producer.produce_many_sync(first_batch)

# Start Karafka and set up a producer thread that will send the second batch
# after the first one is processed
producer_thread = Thread.new do
  # Wait for first batch to be processed
  sleep(0.5) while DT[:processed].size < 15

  # Switch to payload-based partitioning
  DT[:use_payload_based] = true

  # Produce second batch with payload-based partitioning
  Karafka::App.producer.produce_many_sync(second_batch)
end

# Start Karafka and wait for all messages to be processed
start_karafka_and_wait_until do
  DT[:processed].size >= 30
end

# Make sure producer thread has completed
producer_thread.join if producer_thread.alive?

# Analyze the distribution patterns for first batch (key-based)
first_batch_keys = first_batch.map { |m| m[:key] }
first_batch_segments = {}

DT[:processed].each do |segment, key, _|
  next unless first_batch_keys.include?(key)

  # Track which segment processed this key
  first_batch_segments[key] = segment
end

# Verify key-based distribution for first batch
first_batch_segments.each do |key, actual_segment|
  expected_segment = expected_key_segments[key]
  assert_equal(
    expected_segment,
    actual_segment,
    "Key #{key} should be processed by segment #{expected_segment}, was #{actual_segment}"
  )
end

# Analyze the distribution patterns for second batch (payload-based)
second_batch_payloads = second_batch.map { |m| m[:payload] }.uniq
second_batch_payload_segments = {}

DT[:processed].each do |segment, _, payload|
  next unless second_batch_payloads.include?(payload)

  # Track which segment processed this payload
  second_batch_payload_segments[payload] ||= []
  second_batch_payload_segments[payload] << segment
end

# Verify payload-based distribution for second batch
# For each unique payload, all messages should go to the same segment
second_batch_payload_segments.each do |payload, segments|
  assert_equal(
    1,
    segments.uniq.size,
    "Messages with payload #{payload} should all go to the same segment"
  )

  # Verify the segment matches our pre-calculated expectation
  expected_segment = expected_payload_segments[payload]
  actual_segment = segments.first
  assert_equal(
    expected_segment,
    actual_segment,
    "Payload #{payload} should be processed by segment #{expected_segment}, was #{actual_segment}"
  )
end

# Verify distribution patterns are different between key and payload based
key_based_pattern = first_batch_keys.map do |k|
  first_batch_segments[k] if first_batch_segments[k]
end

key_based_pattern.compact!

payload_based_pattern = second_batch_payloads.map do |p|
  second_batch_payload_segments[p].first if second_batch_payload_segments[p]
end

payload_based_pattern.compact!

# There should be evidence that distribution changed
assert !key_based_pattern.empty?, "No key-based distribution detected"
