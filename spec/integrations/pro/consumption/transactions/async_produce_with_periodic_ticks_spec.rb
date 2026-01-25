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

# This test verifies that transactions with async productions work correctly when using
# periodic ticks. Ensures that both consume and tick methods can safely use transactions
# with async productions.
#
# Note: This spec works correctly regardless of how Kafka batches messages for delivery.

setup_karafka do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.max_messages = 5
end

DT[:consume_messages] = []
DT[:tick_messages] = []
DT[:tick_calls] = 0

class Consumer < Karafka::BaseConsumer
  def consume
    transaction do
      messages.each do |message|
        producer.produce_async(
          topic: DT.topics[1],
          payload: "consume_#{message.raw_payload}"
        )
      end

      mark_as_consumed(messages.last) unless messages.empty?
    end
  end

  def tick
    DT[:tick_calls] += 1

    return if DT[:tick_calls] > 5

    transaction do
      producer.produce_async(
        topic: DT.topics[1],
        payload: "tick_#{Time.now.to_i}_#{rand(10000)}"
      )
    end
  end
end

class ValidationConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |msg|
      if msg.raw_payload.start_with?("consume_")
        DT[:consume_messages] << msg.raw_payload
      elsif msg.raw_payload.start_with?("tick_")
        DT[:tick_messages] << msg.raw_payload
      end
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    manual_offset_management true
    periodic interval: 100
  end

  topic DT.topics[1] do
    consumer ValidationConsumer
  end
end

produce_many(DT.topics[0], DT.uuids(10))

start_karafka_and_wait_until do
  DT[:consume_messages].size >= 10 &&
    DT[:tick_messages].size >= 3
end

# Verify all consumed messages were produced
assert DT[:consume_messages].size >= 10

# Verify periodic ticks produced messages
assert DT[:tick_messages].size >= 3

# Verify message prefixes
DT[:consume_messages].each { |msg| assert msg.start_with?("consume_") }
DT[:tick_messages].each { |msg| assert msg.start_with?("tick_") }

# Verify offset committed
assert_equal 10, fetch_next_offset
