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

# Stress test for concurrent async productions within transactions.
# This test simulates high-throughput scenarios with:
# 1. Large message batches
# 2. Multiple async productions per message
# 3. Multiple concurrent consumers processing in parallel
#
# This verifies that under concurrent load:
# - All async productions complete successfully
# - No messages are lost
# - Offsets are correctly tracked
# - Transaction atomicity is maintained
#
# Note: This spec works correctly regardless of how Kafka batches messages for delivery.

setup_karafka do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.concurrency = 5
  config.max_messages = 50
end

DT[:batches_processed] = 0
DT[:messages_processed] = []
DT[:target1] = []
DT[:target2] = []
DT[:target3] = []

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:batches_processed] += 1

    transaction do
      messages.each do |message|
        sleep(rand * 0.01)

        3.times do |i|
          producer.produce_async(
            topic: DT.topics[i + 1],
            key: message.key,
            payload: "#{i}_#{message.raw_payload}",
            headers: { "source_offset" => message.offset.to_s }
          )
        end

        DT[:messages_processed] << message.raw_payload
      end

      mark_as_consumed(messages.last)
    end
  end
end

class ValidationConsumer1 < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:target1] << msg.raw_payload }
  end
end

class ValidationConsumer2 < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:target2] << msg.raw_payload }
  end
end

class ValidationConsumer3 < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:target3] << msg.raw_payload }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    manual_offset_management true
  end

  topic DT.topics[1] do
    consumer ValidationConsumer1
  end

  topic DT.topics[2] do
    consumer ValidationConsumer2
  end

  topic DT.topics[3] do
    consumer ValidationConsumer3
  end
end

message_count = 200
test_messages = DT.uuids(message_count)
produce_many(DT.topics[0], test_messages)

start_karafka_and_wait_until do
  DT[:messages_processed].size >= message_count &&
    DT[:target1].size >= message_count &&
    DT[:target2].size >= message_count &&
    DT[:target3].size >= message_count
end

sleep(2)

# Verify all messages processed exactly once
assert_equal message_count, DT[:messages_processed].uniq.size
assert_equal message_count, DT[:messages_processed].size

# Verify all async productions completed
assert_equal message_count, DT[:target1].size
assert_equal message_count, DT[:target2].size
assert_equal message_count, DT[:target3].size

# Verify message prefixes
DT[:target1].each { |msg| assert msg.start_with?("0_") }
DT[:target2].each { |msg| assert msg.start_with?("1_") }
DT[:target3].each { |msg| assert msg.start_with?("2_") }

# Verify offset committed
assert_equal message_count, fetch_next_offset

# Verify multiple batches processed
assert DT[:batches_processed] > 1
