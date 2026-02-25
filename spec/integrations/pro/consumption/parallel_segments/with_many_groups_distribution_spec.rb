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

# With many segment groups, distribution should remain balanced and consistent with the reducer
# formula

setup_karafka do |config|
  config.concurrency = 15
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    messages.each do |message|
      DT[:assignments] << [message.key, segment_id]
      DT[segment_id] << message.raw_payload
    end
  end
end

# Use a higher number of segments to test scaling
segment_count = 8

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: segment_count,
      partitioner: ->(message) { message.raw_key }
    )

    topic DT.topic do
      consumer Consumer
    end
  end
end

# Create a large set of messages with unique keys
message_count = 200
unique_keys = Array.new(message_count) { |i| "key-#{i}" }

# Pre-calculate which segment each key should go to based on the reducer formula
expected_distribution = {}
segment_counts = Hash.new(0)

unique_keys.each do |key|
  target_segment = key.to_s.sum % segment_count
  expected_distribution[key] = target_segment
  segment_counts[target_segment] += 1
end

messages = unique_keys.map do |key|
  {
    topic: DT.topic,
    key: key,
    payload: "payload-for-#{key}"
  }
end

# Produce all messages
Karafka::App.producer.produce_many_sync(messages)

# Start Karafka and wait for processing
start_karafka_and_wait_until do
  # Wait until we've processed all messages
  DT[:assignments].size >= message_count
end

# Verify each message went to the expected segment
actual_distribution = {}
actual_segment_counts = Hash.new(0)

DT[:assignments].each do |key, segment|
  actual_distribution[key] = segment
  actual_segment_counts[segment] += 1
end

# Find keys assigned to unexpected segments
misrouted_keys = []
unique_keys.each do |key|
  next if actual_distribution[key] == expected_distribution[key]

  misrouted_keys << [key, expected_distribution[key], actual_distribution[key]]
end

assert_equal(
  [],
  misrouted_keys,
  "Some keys were routed to unexpected segments: #{misrouted_keys}"
)

# Verify distribution is balanced
avg_messages = segment_counts.values.sum / segment_counts.size.to_f

# Calculate standard deviation to measure balance
squared_diffs = segment_counts.values.map { |count| (count - avg_messages)**2 }
std_dev = Math.sqrt(squared_diffs.sum / segment_counts.size)

# The distribution should be reasonably balanced
# For a uniform random distribution, std_dev should be small relative to the average
balance_ratio = std_dev / avg_messages
assert(
  balance_ratio < 0.5,
  "Distribution is unbalanced. Std Dev: #{std_dev}, Avg: #{avg_messages}, Ratio: #{balance_ratio}"
)

# Verify each segment received messages
segment_count.times do |i|
  assert(
    actual_segment_counts[i] > 0,
    "Segment #{i} received no messages"
  )
end

# Verify the actual distribution matches expected counts
segment_count.times do |i|
  expected = segment_counts[i]
  actual = actual_segment_counts[i]

  assert_equal(
    expected, actual,
    "Segment #{i} received #{actual} messages, expected #{expected}"
  )
end
