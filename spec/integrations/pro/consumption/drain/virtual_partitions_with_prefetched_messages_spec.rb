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

# When virtual partitions get batches drained from a full prefetch queue, the order inside of each
# virtual partition and the committed offset should be the same as without the drain.
#
# Small partition fetches and a slow first batch make librdkafka queue more messages before we
# poll again, so later batches are drained.

KEYS = 5
TOTAL = 500

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 100
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each do |message|
      DT[message.key] << message.offset
      DT[:all] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(message) { message.key }
    )
  end
end

Karafka.producer.produce_many_sync(
  Array.new(TOTAL) do |i|
    { topic: DT.topic, key: (i % KEYS).to_s, payload: DT.uuid }
  end
)

start_karafka_and_wait_until do
  DT[:all].size >= TOTAL
end

KEYS.times do |key|
  assert_equal (0...TOTAL).select { |offset| offset % KEYS == key }, DT[key.to_s]
end

assert_equal (0...TOTAL).to_a, DT[:all].sort
assert_equal TOTAL, fetch_next_offset
