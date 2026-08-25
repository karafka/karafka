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

# The compensator refreshes two lag fields: consumer_lag (vs the committed offset) and
# consumer_lag_stored (vs the stored offset). The other specs only assert consumer_lag, so this one
# covers the stored path: a paused partition with a stored offset must report a growing
# consumer_lag_stored, not a frozen one.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Stores (and commits) the offset, so both stored_offset and committed_offset are set
    mark_as_consumed!(messages.last)

    return if DT.key?(:paused)

    pause(messages.last.offset, 1_000_000)
    DT[:paused] = true
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  event[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:lags_stored] << partition_values["consumer_lag_stored"]
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

Thread.new do
  sleep(0.1) until DT.key?(:paused)

  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(0.3)

    break if DT[:lags_stored].size >= 20
  end
end

start_karafka_and_wait_until do
  DT[:lags_stored].size >= 25
end

# The stored-offset lag is refreshed just like consumer_lag; frozen it would stay <= ~2
assert DT[:lags_stored].max >= 15, "consumer_lag_stored not compensated, got max #{DT[:lags_stored].max}"
