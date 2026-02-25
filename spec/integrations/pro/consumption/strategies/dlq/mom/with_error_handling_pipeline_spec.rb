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

# Same as pure DLQ version until rebalance

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class LastConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << [message.offset, message.raw_payload]
    end
  end
end

draw_routes do
  4.times do |i|
    topic DT.topics[i] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[i + 1], max_retries: 1)
      manual_offset_management(true)
    end
  end

  topic DT.topics[4] do
    consumer LastConsumer
    manual_offset_management(true)
  end
end

Karafka.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "consumer.consume.error"

  DT[:errors] << 1
end

elements = DT.uuids(1)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:broken)
end

assert_equal 1, DT[:broken].size
# This message will get new offset (first)
assert_equal DT[:broken][0][0], 0
assert_equal DT[:broken][0][1], elements[0]
