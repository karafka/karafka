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

# Lag is derived from the committed (or stored) offset, so with nothing committed there is no base
# to compute it from and librdkafka reports consumer_lag as -1. The compensator must respect that:
# it may refresh the end offset (ls_offset), but it must NOT fabricate a consumer_lag out of a
# negative committed offset. This uses manual offset management and never marks, so the offset stays
# uncommitted, and asserts the end offset IS refreshed while the lag stays untouched.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Deliberately never mark: no committed and no stored offset for this partition
    return if DT.key?(:paused)

    pause(messages.last.offset, 1_000_000)
    DT[:paused] = true
  end
end

draw_routes do
  topic(DT.topic) do
    consumer Consumer
    manual_offset_management(true)
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  event[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:ls_offsets] << partition_values["ls_offset"]
      DT[:consumer_lags] << partition_values["consumer_lag"]
    end
  end
end

produce_many(DT.topic, DT.uuids(1))

Thread.new do
  sleep(0.1) until DT.key?(:paused)

  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(0.3)

    break if DT[:ls_offsets].size >= 20
  end
end

start_karafka_and_wait_until do
  DT[:ls_offsets].size >= 25
end

# The end offset IS refreshed (compensation ran and the partition qualified) ...
assert DT[:ls_offsets].max >= 15, "end offset was not refreshed, got max #{DT[:ls_offsets].max}"
# ... but with nothing committed the lag must stay -1: compensation must not invent one
assert DT[:consumer_lags].max <= 0, "lag fabricated without a committed offset, got max #{DT[:consumer_lags].max}"
