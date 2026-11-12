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

# When a delayed topic pauses on messages that are too young while more of them are already
# prefetched, none of them should be delivered before the delay and there should be no gap or
# duplicate.
#
# Small partition fetches and steady production keep librdkafka queue full of messages, some of
# them still too young, so batches are drained.

DELAY = 2_000
TOTAL = 400

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    now = Time.now.to_f * 1_000

    messages.each do |message|
      DT[:offsets] << message.offset
      DT[:ages] << (now - (message.timestamp.to_f * 1_000))
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    delay_by(DELAY)
  end
end

producer = Thread.new do
  (TOTAL / 20).times do
    produce_many(DT.topic, DT.uuids(20))
    sleep(0.2)
  end
end

start_karafka_and_wait_until do
  DT[:offsets].size >= TOTAL
end

producer.join

assert_equal (0...TOTAL).to_a, DT[:offsets]
# Timestamps have a millisecond precision
assert DT[:ages].min >= DELAY - 1, DT[:ages].min
