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

# When throttling seeks back to the first throttled message while more messages of the partition
# are already prefetched, none of the held back messages should be delivered early and there
# should be no gap or duplicate.
#
# Small partition fetches and a slow first batch make librdkafka queue more messages before we
# poll again, so later batches are drained.

TOTAL = 200
LIMIT = 50
INTERVAL = 2_000

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each { |message| DT[:offsets] << message.offset }

    DT[:times] << Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1_000
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    throttling(
      limit: LIMIT,
      interval: INTERVAL
    )
  end
end

produce_many(DT.topic, DT.uuids(TOTAL))

start_karafka_and_wait_until do
  DT[:offsets].size >= TOTAL
end

assert_equal (0...TOTAL).to_a, DT[:offsets]

# The throttler is a sliding window, so TOTAL messages need at least this many full intervals.
# Held back messages delivered from the prefetch would shorten it
span = DT[:times].last - DT[:times].first
assert span >= (((TOTAL / LIMIT) - 1) * INTERVAL) - 1_000, span
