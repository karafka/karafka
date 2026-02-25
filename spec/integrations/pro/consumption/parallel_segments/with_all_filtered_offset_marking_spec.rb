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

# When all messages are filtered out, offsets should be marked as consumed to prevent lag

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
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key }
    )

    topic DT.topic do
      consumer Consumer
    end
  end
end

# Generate keys that will only route to groups 0 and 1, none to group 2
group0_keys_payloads = []
group1_keys_payloads = []

100.times do |i|
  key = "key-#{i}"
  payload = "payload-#{i}"

  # Calculate which group this will go to
  group_id = key.to_s.sum % 3

  case group_id
  when 0
    group0_keys_payloads << [key, payload]
  when 1
    group1_keys_payloads << [key, payload]
  end
end

group0_keys_payloads = group0_keys_payloads.first(10)
group1_keys_payloads = group1_keys_payloads.first(10)

# Create messages only for groups 0 and 1
group0_messages = []
group0_payloads = []
group0_keys_payloads.each do |key, payload|
  group0_messages << { topic: DT.topic, key: key, payload: payload }
  group0_payloads << payload
end

group1_messages = []
group1_payloads = []
group1_keys_payloads.each do |key, payload|
  group1_messages << { topic: DT.topic, key: key, payload: payload }
  group1_payloads << payload
end

# No messages for group 2 - we want to test if offsets are marked when all filtered

# We mix them so their dispatch is mixed
combined = []
group0_messages.each_with_index do |message, index|
  combined << message
  combined << group1_messages[index]
end

Karafka::App.producer.produce_many_sync(combined)

start_karafka_and_wait_until do
  DT[0].size >= 10 && DT[1].size >= 10
end

# Verify group 0 and 1 received their messages
assert_equal group0_payloads, DT[0]
assert_equal group1_payloads, DT[1]

# Verify group 2 received no messages
assert_equal 0, DT[2].size

# Get the consumer group IDs for all segments
segment0_group_id = "#{DT.consumer_group}-parallel-0"
segment1_group_id = "#{DT.consumer_group}-parallel-1"
segment2_group_id = "#{DT.consumer_group}-parallel-2"

# Verify that offsets are marked for all segments, including segment 2 that filtered everything
segment0_offset = fetch_next_offset(DT.topic, consumer_group_id: segment0_group_id)
segment1_offset = fetch_next_offset(DT.topic, consumer_group_id: segment1_group_id)
segment2_offset = fetch_next_offset(DT.topic, consumer_group_id: segment2_group_id)

# All three segments should have marked offsets
assert segment0_offset > 0
assert segment1_offset > 0
assert segment2_offset > 0

# Verify lag is zero for all segments
offsets_with_lags = Karafka::Admin.read_lags_with_offsets

segment0_lag = offsets_with_lags.fetch(segment0_group_id).fetch(DT.topic)[0].fetch(:lag)
segment1_lag = offsets_with_lags.fetch(segment1_group_id).fetch(DT.topic)[0].fetch(:lag)
segment2_lag = offsets_with_lags.fetch(segment2_group_id).fetch(DT.topic)[0].fetch(:lag)

assert(segment0_lag <= 1, segment0_lag)
assert(segment1_lag <= 1, segment1_lag)
assert_equal(0, segment2_lag, segment2_lag)
