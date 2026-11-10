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

# Karafka::Admin.copy_dead_letter_queue with a target topic should copy messages the Pro DLQ
# dispatched to that topic instead of their source topic, keeping the original key and headers.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 1

      mark_as_consumed message
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end

  topic DT.topics[1] do
    active false
  end
end

Karafka::Admin.create_topic(DT.topics[2], 1, 1)

elements = DT.uuids(3)
produce_many(DT.topics[0], elements, key: "key", headers: { "user" => "value" })

start_karafka_and_wait_until do
  Karafka::Admin.read_watermark_offsets(DT.topics[1], 0).last >= 1
end

# Karafka closes its producer when it stops
producer = WaterDrop::Producer.new do |config|
  config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

copied = Karafka::Admin.copy_dead_letter_queue(
  DT.topics[1],
  target_topic_name: DT.topics[2],
  producer: producer
)

assert_equal 1, copied

replayed = Karafka::Admin.read_topic(DT.topics[2], 0, 10, 0)

assert_equal [elements[1]], replayed.map(&:raw_payload)
assert_equal "key", replayed.first.raw_key
assert_equal({ "user" => "value", "replay_count" => "1" }, replayed.first.raw_headers)
assert_equal 3, Karafka::Admin.read_watermark_offsets(DT.topics[0], 0).last

producer.close
