# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# This test verifies async production failure handling within transactions:
# 1. Produces 15 messages (offsets 0-14) to a topic
# 2. Each message produces async to its own unique target topic
# 3. mark_as_consumed is called after all async productions
# 4. On first attempt processing offset 1, inject a failure (offset 1 may or may not share a batch
#    with offset 0, depending on how Kafka delivers the data)
#
# We verify that if the transaction completes without error, all async productions
# have been successfully acknowledged, so the callback cannot indicate failure later.
# This tests 15 total messages across 15 different topics.
#
# Note: This spec works correctly regardless of how Kafka batches messages for delivery.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.max_messages = 3
end

# Initialize counters and collections
DT[:consume_attempts] = 0
DT[:total_received] = 0
DT[:processed_offsets] = []
DT[:successful_attempts] = []
DT[:failed_attempts] = []
DT[:errors] = []
DT[:handler_statuses] = []
DT[:unexpected_failures] = []
DT[:received_by_topic] = Hash.new { |h, k| h[k] = [] }

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume_attempts] += 1
    attempt_id = DT[:consume_attempts]

    # Track which offsets we're processing
    first_offset = messages.first.offset

    # Only fail on the first batch that contains offset 1. We do not require it to start from
    # offset 0, as the first batch may hold only offset 0 when polled before the rest is fetched
    should_fail = !DT.key?(:failed) && messages.any? { |message| message.offset == 1 }

    handlers = []

    begin
      transaction do
        messages.each do |message|
          DT[:processed_offsets] << message.offset

          # On the first batch with offset 1, inject a failure for it
          if should_fail && message.offset == 1
            DT[:failed] = true

            # This should cause the entire transaction to fail
            raise StandardError, "Production failure for offset 1 in first attempt"
          end

          # Each message goes to its own unique target topic based on offset
          target_topic = DT.topics[message.offset + 1]

          handler = producer.produce_async(
            topic: target_topic,
            payload: "attempt#{attempt_id}_offset#{message.offset}_#{message.raw_payload}"
          )

          handlers << {
            attempt: attempt_id,
            offset: message.offset,
            handler: handler,
            payload: message.raw_payload,
            target_topic: target_topic
          }
        end

        # This mark should only succeed if ALL async productions succeeded
        mark_as_consumed(messages.last)
      end

      # If we get here, transaction committed successfully
      DT[:successful_attempts] << attempt_id

      # Verify all handlers report success
      handlers.each do |handler_info|
        result = handler_info[:handler].wait

        DT[:handler_statuses] << {
          attempt: handler_info[:attempt],
          offset: handler_info[:offset],
          target_topic: handler_info[:target_topic],
          error: result.error,
          result_offset: result.offset,
          partition: result.partition,
          payload: handler_info[:payload]
        }

        # If transaction completed, all handlers must have been delivered successfully
        next unless result.error

        DT[:unexpected_failures] << {
          attempt: handler_info[:attempt],
          offset: handler_info[:offset],
          error: result.error
        }
      end
    rescue => e
      DT[:failed_attempts] << attempt_id
      DT[:errors] << {
        attempt: attempt_id,
        first_offset: first_offset,
        message: e.message
      }
      # Transaction rolled back, re-raise to trigger retry
      raise
    end
  end
end

class ValidationConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |msg|
      DT[:received_by_topic][topic.name] << msg.raw_payload
      DT[:total_received] += 1
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    manual_offset_management true
  end

  # Create 15 target topics (5 batches * 3 messages each)
  15.times do |i|
    topic DT.topics[i + 1] do
      consumer ValidationConsumer
    end
  end
end

# Produce 15 messages to the topic
# Kafka may deliver these in any batch size combination
test_messages = Array.new(15) { |i| "msg#{i}_#{DT.uuid}" }

produce_many(DT.topics[0], test_messages)

start_karafka_and_wait_until do
  DT[:total_received] >= 15
end

# Verify at least one failed attempt
assert DT[:failed_attempts].size >= 1

# Verify exactly one error
assert_equal 1, DT[:errors].size
assert DT[:errors].first[:first_offset] <= 1
assert DT[:errors].first[:message].include?("offset 1")

# Verify all 15 messages were eventually produced and received
assert_equal 15, DT[:total_received]

# Verify each target topic received exactly one message
15.times do |i|
  topic_name = DT.topics[i + 1]
  messages = DT[:received_by_topic][topic_name]
  assert_equal 1, messages.size
end

# Verify all handlers from successful transactions report no errors
assert_equal 15, DT[:handler_statuses].size

DT[:handler_statuses].each do |handler|
  assert handler[:error].nil?
  assert handler[:result_offset] >= 0
  assert handler[:partition] >= 0
end

# Verify no unexpected failures occurred after transaction commit
assert_equal 0, DT[:unexpected_failures].size

# Verify offset committed correctly (15 messages)
assert_equal 15, fetch_next_offset

# Verify we processed offset 0 at least twice (initial fail + retry) when it was in the failed batch
offset_0_attempts = DT[:processed_offsets].count(0)
assert offset_0_attempts >= (DT[:errors].first[:first_offset].zero? ? 2 : 1)

# Verify we processed offset 1 at least twice (failed on first, succeeded on retry)
offset_1_attempts = DT[:processed_offsets].count(1)
assert offset_1_attempts >= 2

# Verify offsets 2-14 were each processed at least once
(2..14).each do |offset|
  assert DT[:processed_offsets].include?(offset)
end
