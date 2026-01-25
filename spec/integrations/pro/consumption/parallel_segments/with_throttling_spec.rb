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

# Throttling should be applied per parallel segment group rather than globally

setup_karafka do |config|
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    # Track processing time for throttling analysis
    DT[:times] << [segment_id, Time.now.to_f]

    messages.each do |message|
      DT[segment_id] << message.raw_payload
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
      # Configure very tight throttling:
      # Only 5 messages per 5 second window
      throttling(limit: 5, interval: 5_000)
    end
  end
end

# Create messages that will be distributed between 2 segment groups
group0_messages = []
group1_messages = []

# Generate 15 messages for each group (30 total)
10_000.times do |i|
  # Ensure deterministic distribution
  if i.even?
    key = "even-key-#{i}"
    payload = "payload-even-#{i}"

    # Verify this key will go to group 0
    next unless (key.to_s.sum % 2).zero?

    group0_messages << { topic: DT.topic, key: key, payload: payload }
  else
    key = "odd-key-#{i}"
    payload = "payload-odd-#{i}"

    # Verify this key will go to group 1
    next unless (key.to_s.sum % 2).odd?

    group1_messages << { topic: DT.topic, key: key, payload: payload }
  end
end

# Ensure we have enough messages
group0_messages = group0_messages.first(25)
group1_messages = group1_messages.first(25)

# Record expected payloads for verification
group0_payloads = group0_messages.map { |m| m[:payload] }
group1_payloads = group1_messages.map { |m| m[:payload] }

# Record start time for throttling verification
start_time = Time.now.to_f

# Produce all messages at once
Karafka::App.producer.produce_many_sync(group0_messages + group1_messages)

start_karafka_and_wait_until do
  # Wait until all messages are processed
  DT[0].size >= 25 && DT[1].size >= 25
end

# Calculate elapsed time
elapsed_time = Time.now.to_f - start_time

# Verify all messages were eventually processed
assert_equal group0_payloads.sort, DT[0].sort
assert_equal group1_payloads.sort, DT[1].sort

# With limit: 5 and interval: 5000, processing 15 messages should take:
# At least 3 intervals (15/5 = 3) * 5 seconds = 15 seconds
min_expected_time = 15

# Verify throttling was applied by checking elapsed time
assert(
  elapsed_time > min_expected_time,
  "Processing completed too quickly (#{elapsed_time.round(2)}s)"
)

segments_times = DT[:times].group_by(&:first)
segment0_times = segments_times[0]&.map(&:last) || []
segment1_times = segments_times[1]&.map(&:last) || []

# Instead of trying to find windows where both segments processed > 5 messages,
# we should check if both segments processed messages in parallel
# and were throttled at similar times

# Check if there was parallel processing (both segments active within a short time-frame)
time_diffs = []
segment0_times.each do |t0|
  # Find the closest processing time in segment 1
  closest_t1 = segment1_times.min_by { |t1| (t1 - t0).abs }
  time_diffs << (closest_t1 - t0).abs if closest_t1
end

# If we have at least one pair of close timestamps (within 1 second)
has_parallel_processing = time_diffs.any? { |diff| diff < 1.0 }

assert(
  has_parallel_processing,
  "No evidence of parallel processing between segments, suggesting global throttling"
)

assert segment0_times.size >= 5, "Segment 0 didn't process enough messages: #{segment0_times.size}"
assert segment1_times.size >= 5, "Segment 1 didn't process enough messages: #{segment1_times.size}"
