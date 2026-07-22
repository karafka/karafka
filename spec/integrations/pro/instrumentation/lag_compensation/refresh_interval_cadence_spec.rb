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

# The end offsets are re-queried at most once per configured interval, not on every statistics
# emission. With a refresh interval several times larger than the statistics interval, the
# compensated lag advances in a few discrete steps (one per refresh) even though many statistics
# events are emitted in between - it does not track the backlog continuously. Guards the
# IntervalRunner gating in the refresher.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  # Refresh six times less often than statistics are emitted
  config.internal.statistics.consumer_groups.lag_compensation.interval = 3_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

class Consumer < Karafka::BaseConsumer
  def consume
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

      DT[:lags] << partition_values["consumer_lag"]
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

    break if DT[:lags].size >= 30
  end
end

# Collect plenty of emissions (~17s) so several refresh intervals elapse
start_karafka_and_wait_until do
  DT[:lags].size >= 35
end

# Compensation did happen ...
assert DT[:lags].max >= 15, "expected compensation to kick in, got max #{DT[:lags].max}"
# ... but the compensated lag advanced in a handful of steps (one per refresh interval), far fewer
# than the number of statistics emissions - it is not refreshed on every emit
distinct = DT[:lags].uniq.size
assert distinct <= 10, "expected stepped compensation (few distinct values), got #{distinct} across #{DT[:lags].size} emits"
