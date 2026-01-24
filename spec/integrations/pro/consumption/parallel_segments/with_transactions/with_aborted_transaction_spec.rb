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

# When a transaction is aborted, the parallel segments should handle this properly without marking
# offsets

setup_karafka do |config|
  config.concurrency = 5
  config.max_messages = 10
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    # Detect if this batch contains an abort trigger
    contains_abort = messages.any? { |m| m.raw_payload.include?('abort-trigger') }

    # Store what we received before any processing
    messages.each do |message|
      DT[:received] << {
        key: message.key,
        payload: message.raw_payload,
        segment_id: segment_id,
        contains_abort: contains_abort
      }
    end

    # Process with the appropriate strategy
    if contains_abort
      # Process a batch with abort - it should abort the transaction
      transaction do
        messages.each do |message|
          # Try to produce something (should be rolled back)
          produce_async(
            topic: DT.topics[1],
            key: message.key,
            payload: "processed-#{message.raw_payload}"
          )

          next unless message.raw_payload.include?('abort-trigger')

          DT[:aborted] << {
            key: message.key,
            segment_id: segment_id
          }

          raise WaterDrop::AbortTransaction
        end

        # This should never execute for batches with abort-trigger
        mark_as_consumed(messages.last)
      end
    else
      # Normal processing for batches without abort triggers
      transaction do
        messages.each do |message|
          produce_async(
            topic: DT.topics[1],
            key: message.key,
            payload: "processed-#{message.raw_payload}"
          )
        end

        # Mark the batch as processed
        mark_as_consumed(messages.last)

        # Track successful processing
        DT[:normal_processed] << {
          count: messages.size,
          segment_id: segment_id
        }
      end
    end

    # Increment counter to help terminate the test
    DT[:batches_processed] << 1
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 2,
      partitioner: ->(message) { message.raw_key }
    )
    topic DT.topics[0] do
      consumer Consumer
    end

    # Add the target topic to the routing so it's correctly recognized by read_topic
    topic DT.topics[1] do
      active false
    end
  end
end

# Create two sets of messages - one with an abort trigger, one without
segment0_normal = []
segment1_normal = []
segment0_abort = []

# Create normal messages for segment 0
5.times do |i|
  key = "s0-normal-#{i}"
  # Ensure it maps to segment 0
  key = "#{key}-fixed" unless key.to_s.sum.even?

  segment0_normal << {
    topic: DT.topics[0],
    key: key,
    payload: "normal-payload-s0-#{i}"
  }
end

# Create normal messages for segment 1
5.times do |i|
  key = "s1-normal-#{i}"
  # Ensure it maps to segment 1
  key = "#{key}-fixed" unless key.to_s.sum.odd?

  segment1_normal << {
    topic: DT.topics[0],
    key: key,
    payload: "normal-payload-s1-#{i}"
  }
end

# Create a message with abort trigger for segment 0
abort_key = 'abort-key'
# Ensure it maps to segment 0
abort_key = "#{abort_key}-fixed" unless abort_key.to_s.sum.even?

segment0_abort << {
  topic: DT.topics[0],
  key: abort_key,
  payload: 'abort-trigger'
}

Karafka::App.producer.produce_many_sync(segment0_normal + segment1_normal)
Karafka::App.producer.produce_many_sync(segment0_abort)

# Start Karafka and wait for a fixed number of batches to be processed
start_karafka_and_wait_until do
  # Wait for EITHER enough batches OR we've seen what we need
  received_abort = DT[:aborted].size >= 1
  processed_normal = DT[:normal_processed].size >= 1
  enough_batches = DT[:batches_processed].size >= (
    segment0_normal.size + segment1_normal.size + segment0_abort.size
  )

  (received_abort && processed_normal) || enough_batches
end

# 1. Verify we've received both normal and abort messages
received_payloads = DT[:received].map { |r| r[:payload] }
normal_payloads = segment0_normal.map { |m| m[:payload] } + segment1_normal.map { |m| m[:payload] }
abort_payloads = segment0_abort.map { |m| m[:payload] }

normal_received = normal_payloads.all? { |p| received_payloads.include?(p) }
abort_received = abort_payloads.all? { |p| received_payloads.include?(p) }

assert(
  normal_received,
  'Not all normal messages were received'
)

assert(
  abort_received,
  'Not all abort messages were received'
)

# 2. Verify we detected an abort
assert(
  !DT[:aborted].empty?,
  'Expected to detect at least one aborted transaction'
)

# 3. Get messages from the target topic using Karafka::Admin
produced_messages = []
# Read from partition 0 (adjust if needed)
target_messages = Karafka::Admin.read_topic(DT.topics[1], 0, 100)
produced_messages.concat(target_messages)

# If there are multiple partitions, read from each one
if target_messages.empty?
  # Try partition 1 as well
  more_messages = Karafka::Admin.read_topic(DT.topics[1], 1, 100)
  produced_messages.concat(more_messages)
end

# Extract the key and payload for easier comparison
produced_data = produced_messages.map do |message|
  {
    key: message.key,
    payload: message.raw_payload
  }
end

# 4. Verify abort messages weren't produced
abort_keys = segment0_abort.map { |m| m[:key] }
produced_keys = produced_data.map { |m| m[:key] }

abort_keys_in_target = abort_keys & produced_keys
assert_equal(
  [],
  abort_keys_in_target,
  'Messages from aborted transactions should not appear in target topic'
)

# 5. Verify at least some normal messages were produced
normal_keys = segment0_normal.map { |m| m[:key] } + segment1_normal.map { |m| m[:key] }
normal_keys_in_target = normal_keys & produced_keys

assert(
  !normal_keys_in_target.empty?,
  'Expected normal messages to be produced to target topic, but found none. ' \
  "Received: #{DT[:received].size}, Aborted: #{DT[:aborted].size}, " \
  "Normal processed: #{DT[:normal_processed].size}, " \
  "Produced messages: #{produced_data.size}"
)

# 6. Get committed offsets to verify they were only marked for successful transactions
segment0_group_id = "#{DT.consumer_group}-parallel-0"
segment1_group_id = "#{DT.consumer_group}-parallel-1"

segment0_offset = fetch_next_offset(DT.topics[0], consumer_group_id: segment0_group_id)
segment1_offset = fetch_next_offset(DT.topics[0], consumer_group_id: segment1_group_id)

# Both segments should have committed some offsets from successful transactions
assert(segment0_offset > 0, 'Segment 0 did not commit any offsets')
assert(segment1_offset > 0, 'Segment 1 did not commit any offsets')
