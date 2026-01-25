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
    messages.each do |message|
      raise StandardError if message.offset == 10

      DT[:offsets] << message.offset

      mark_as_consumed message
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << [message.offset, message.raw_payload]
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 2)
    manual_offset_management(true)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
    manual_offset_management(true)
  end
end

Karafka.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "consumer.consume.error"

  DT[:errors] << 1
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:offsets].uniq.size >= 99 && DT.key?(:broken)
end

# first error and two errors on retries prior to moving on
assert_equal 3, DT[:errors].size

# we should not have the message that was failing
assert_equal (0..99).to_a - [10], DT[:offsets]

assert_equal 1, DT[:broken].size
# This message will get new offset (first)
assert_equal DT[:broken][0][0], 0
assert_equal DT[:broken][0][1], elements[10]
