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

# This test verifies that when one of multiple produce_async operations fails within a transaction,
# the entire transaction rolls back including:
# 1. No messages are committed to any target topics
# 2. The offset is not marked as consumed
# 3. Messages can be reprocessed
#
# Note: This spec works correctly regardless of how Kafka batches messages for delivery.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.max_messages = 5
end

DT[:attempts] = 0
DT[:processing] = []
DT[:errors] = []
DT[:target1] = []
DT[:target2] = []
DT[:success] = false

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT[:attempts] >= 2

    DT[:attempts] += 1

    begin
      transaction do
        messages.each_with_index do |message, index|
          DT[:processing] << message.raw_payload

          producer.produce_async(
            topic: DT.topics[1],
            payload: "target1_#{message.raw_payload}"
          )

          if DT[:attempts] == 1 && index == 1
            raise StandardError, "Simulated production failure"
          end

          producer.produce_async(
            topic: DT.topics[2],
            payload: "target2_#{message.raw_payload}"
          )
        end

        mark_as_consumed(messages.last)
      end

      DT[:success] = true
    rescue => e
      DT[:errors] << e.message
      raise
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
end

produce_many(DT.topics[0], DT.uuids(3))

start_karafka_and_wait_until do
  DT[:success] == true && DT[:target1].size >= 3 && DT[:target2].size >= 3
end

# Verify one failure and one success
assert_equal 2, DT[:attempts]
assert_equal 1, DT[:errors].size

# Verify messages processed (2 on failed attempt + 3 on successful attempt = 5 total)
assert_equal 5, DT[:processing].size

# Verify all messages eventually produced to both targets
assert_equal 3, DT[:target1].size
assert_equal 3, DT[:target2].size

# Verify offset committed only on successful attempt
assert_equal 3, fetch_next_offset
