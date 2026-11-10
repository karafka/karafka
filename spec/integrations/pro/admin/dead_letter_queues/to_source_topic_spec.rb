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

# Karafka::Pro::Admin::DeadLetterQueues.copy without a target topic should copy messages the Pro DLQ
# dispatched back to their source topic and partition, with the original key and headers, without
# the DLQ source headers and with the replay count header. A message that fails again carries the
# replay count to the DLQ, so a second copy increments it.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.raw_payload == DT[:failing]

      mark_as_consumed message
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    config(partitions: 2)
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end

  topic DT.topics[1] do
    active false
  end
end

elements = DT.uuids(5)
DT[:failing] = elements[2]

# This key alone would go to partition 0, so the copy must use the source partition
produce_many(DT.topics[0], elements, partition: 1, key: "key1", headers: { "user" => "value" })

# The message is copied while the app runs, fails again and goes back to the DLQ with its replay
# count
start_karafka_and_wait_until(sleep: 0.5) do
  dlq_high = Karafka::Admin.read_watermark_offsets(DT.topics[1], 0).last

  if dlq_high >= 1 && !DT.key?(:copied)
    DT[:copied] = Karafka::Pro::Admin::DeadLetterQueues.copy(DT.topics[1])
  end

  dlq_high >= 2
end

assert_equal 1, DT[:copied]

replayed = Karafka::Admin.read_topic(DT.topics[0], 1, 1, 5).first

assert_equal elements[2], replayed.raw_payload
assert_equal "key1", replayed.raw_key
assert_equal({ "user" => "value", "replay_count" => "1" }, replayed.raw_headers)
assert_equal [0, 0], Karafka::Admin.read_watermark_offsets(DT.topics[0], 0)

dlq_message = Karafka::Admin.read_topic(DT.topics[1], 0, 1, 1).first

assert_equal "1", dlq_message.raw_headers["replay_count"]
assert_equal "5", dlq_message.raw_headers["source_offset"]

# Karafka closes its producer when it stops
producer = WaterDrop::Producer.new do |config|
  config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

copied = Karafka::Pro::Admin::DeadLetterQueues.copy(DT.topics[1], start_offset: 1, producer: producer)

assert_equal 1, copied
assert_equal "2", Karafka::Admin.read_topic(DT.topics[0], 1, 1, 6).first.raw_headers["replay_count"]

producer.close
