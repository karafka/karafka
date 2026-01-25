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

# This test simulates a realistic batch processing scenario where messages from one topic
# are transformed and dispatched to multiple target topics asynchronously within a transaction.
# Each message produces to multiple topics, creating a fan-out pattern.
#
# This verifies:
# 1. Batch async productions complete atomically
# 2. All target topics receive all expected messages
# 3. Offset marking waits for all async handlers across all topics
# 4. Transaction semantics are preserved in complex multi-topic scenarios
#
# Note: This spec works correctly regardless of how Kafka batches messages for delivery.

setup_karafka do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.max_wait_time = 100
  config.max_messages = 20
end

DT[:done] = false
DT[:processed] = []
DT[:analytics] = []
DT[:notifications] = []
DT[:audit] = []
DT[:archival] = []

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT[:done]

    transaction do
      messages.each do |message|
        data = message.raw_payload

        producer.produce_async(
          topic: DT.topics[1],
          key: message.key,
          payload: "analytics_#{data}"
        )

        producer.produce_async(
          topic: DT.topics[2],
          key: message.key,
          payload: "notifications_#{data}"
        )

        producer.produce_async(
          topic: DT.topics[3],
          key: message.key,
          payload: "audit_#{data}"
        )

        producer.produce_async(
          topic: DT.topics[4],
          key: message.key,
          payload: "archival_#{data}"
        )

        DT[:processed] << data
      end

      mark_as_consumed(messages.last)
    end

    DT[:done] = true if DT[:processed].size >= 20
  end
end

class AnalyticsConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:analytics] << msg.raw_payload }
  end
end

class NotificationsConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:notifications] << msg.raw_payload }
  end
end

class AuditConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:audit] << msg.raw_payload }
  end
end

class ArchivalConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:archival] << msg.raw_payload }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    manual_offset_management true
  end

  topic DT.topics[1] do
    consumer AnalyticsConsumer
  end

  topic DT.topics[2] do
    consumer NotificationsConsumer
  end

  topic DT.topics[3] do
    consumer AuditConsumer
  end

  topic DT.topics[4] do
    consumer ArchivalConsumer
  end
end

test_messages = DT.uuids(20)
produce_many(DT.topics[0], test_messages)

start_karafka_and_wait_until do
  DT[:done] &&
    DT[:analytics].size >= 20 &&
    DT[:notifications].size >= 20 &&
    DT[:audit].size >= 20 &&
    DT[:archival].size >= 20
end

# Verify all messages processed
assert_equal 20, DT[:processed].size

# Verify all target topics received all messages
assert_equal 20, DT[:analytics].size
assert_equal 20, DT[:notifications].size
assert_equal 20, DT[:audit].size
assert_equal 20, DT[:archival].size

# Verify message prefixes
DT[:analytics].each { |msg| assert msg.start_with?("analytics_") }
DT[:notifications].each { |msg| assert msg.start_with?("notifications_") }
DT[:audit].each { |msg| assert msg.start_with?("audit_") }
DT[:archival].each { |msg| assert msg.start_with?("archival_") }

# Verify offset committed
assert_equal 20, fetch_next_offset
