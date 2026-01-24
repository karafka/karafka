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

# During rebalancing, parallel segment assignment should remain consistent for the same messages

setup_karafka do |config|
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    messages.each do |message|
      # Track each message with its key, segment_id, and batch info
      DT[:assignments] << [message.key, segment_id, message.raw_payload]
      # Store message key for verification
      DT[segment_id] << message.key
    end
  end

  def revoked
    # Track when revocation happens
    DT[:revoked] << Time.now.to_f
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

unique_keys = Array.new(20) { |i| "key-#{i}" }

batch1_messages = unique_keys.map do |key|
  { topic: DT.topic, key: key, payload: "batch1-#{key}" }
end

Karafka::App.producer.produce_many_sync(batch1_messages)

# Create a thread that will trigger rebalance after initial processing
consumer = setup_rdkafka_consumer
rebalance_thread = Thread.new do
  # Wait until we've processed the first batch
  sleep(0.5) until DT[0].size + DT[1].size >= 20

  consumer.subscribe(DT.topic)

  5.times do
    consumer.poll(1000)
    sleep(0.5)
  end

  # Now produce second batch with same keys
  batch2_messages = unique_keys.map do |key|
    { topic: DT.topic, key: key, payload: "batch2-#{key}" }
  end

  # Send second batch of messages
  Karafka::App.producer.produce_many_sync(batch2_messages)

  # Poll a bit more
  5.times do
    consumer.poll(1000)
    sleep(0.5)
  end

  # Mark when we're done
  DT[:rebalance_complete] = true
  consumer.close
end

start_karafka_and_wait_until do
  !DT[:revoked].empty? &&
    DT[:rebalance_complete] == true &&
    # We should have processed both batches
    DT[0].size + DT[1].size >= 40
end

rebalance_thread.join

batch1_assignments = {}
batch2_assignments = {}

DT[:assignments].each do |key, segment_id, payload|
  if payload.start_with?('batch1')
    batch1_assignments[key] = segment_id
  elsif payload.start_with?('batch2')
    batch2_assignments[key] = segment_id
  end
end

# Find keys that changed segment assignment between batches
inconsistent_keys = []

unique_keys.each do |key|
  if batch1_assignments[key] && batch2_assignments[key] &&
     batch1_assignments[key] != batch2_assignments[key]
    inconsistent_keys << key
  end
end

# Assert that no keys changed segment assignment
assert_equal(
  [],
  inconsistent_keys,
  "These keys were assigned to different segments after rebalance: #{inconsistent_keys}"
)

# Verify that both segments got messages in each batch
batch1_segment0 = batch1_assignments.values.count(0)
batch1_segment1 = batch1_assignments.values.count(1)
batch2_segment0 = batch2_assignments.values.count(0)
batch2_segment1 = batch2_assignments.values.count(1)

assert batch1_segment0 > 0, 'Segment 0 should have received messages in batch 1'
assert batch1_segment1 > 0, 'Segment 1 should have received messages in batch 1'
assert batch2_segment0 > 0, 'Segment 0 should have received messages in batch 2'
assert batch2_segment1 > 0, 'Segment 1 should have received messages in batch 2'

# The distribution should be the same in both batches
assert_equal(
  batch1_segment0,
  batch2_segment0,
  'Segment 0 should have received the same number of messages in both batches'
)

assert_equal(
  batch1_segment1,
  batch2_segment1,
  'Segment 1 should have received the same number of messages in both batches'
)
