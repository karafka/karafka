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

# Messages should be distributed to consumers based on their group_id assignment using the
# partitioner and reducer

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
      count: 2,
      partitioner: ->(message) { message.raw_key }
    )

    topic DT.topic do
      consumer Consumer
    end
  end
end

# Generate keys and payloads with known distribution
group0_keys_payloads = []
group1_keys_payloads = []

100.times do |i|
  key = "key-#{i}"
  payload = "payload-#{i}"

  # Pre-calculate which group this will go to
  if (key.to_s.sum % 2).zero?
    group0_keys_payloads << [key, payload]
  else
    group1_keys_payloads << [key, payload]
  end
end

group0_keys_payloads = group0_keys_payloads.first(10)
group1_keys_payloads = group1_keys_payloads.first(10)

# Create messages for each group
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

# Verify group 0 received only its messages
assert_equal group0_payloads, DT[0]
# Verify group 1 received only its messages
assert_equal group1_payloads, DT[1]
# Verify all messages were consumed exactly once
assert_equal group0_messages.size + group1_messages.size, DT[0].size + DT[1].size

assert fetch_next_offset(consumer_group_id: Karafka::App.consumer_groups.first.id) >= 19
assert fetch_next_offset(consumer_group_id: Karafka::App.consumer_groups.last.id) >= 19
