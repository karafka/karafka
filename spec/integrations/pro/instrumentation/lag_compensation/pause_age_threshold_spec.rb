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

# A partition is compensated only after it has been paused for at least the pause age. This asserts
# the threshold from BOTH sides on a single long pause: statistics emitted before the pause age is
# reached must still be frozen, and statistics emitted after it must be compensated.
#
# This bites in both directions: if the pause age gate were dropped (compensate any paused
# partition) the early window would already grow and fail; if the feature were off the late window
# would stay frozen and fail.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed!(messages.last)

    return if DT.key?(:paused)

    DT[:paused_at] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    pause(messages.last.offset, 1_000_000)
    DT[:paused] = true
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  DT[:emits] << true
  next unless DT.key?(:paused_at)

  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - DT[:paused_at]

  event[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      lag = partition_values["consumer_lag"]

      # Buckets straddle the 5s pause age with a gap around it to avoid boundary jitter
      if elapsed < 4
        DT[:before_age] << lag
      elsif elapsed > 7
        DT[:after_age] << lag
      end
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

# Keep producing across the whole window; producer stops a few emissions before the server
Thread.new do
  sleep(0.1) until DT.key?(:paused)

  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(0.3)

    break if DT[:emits].size >= 22
  end
end

start_karafka_and_wait_until do
  DT[:emits].size >= 26 && DT[:before_age].size >= 3 && DT[:after_age].size >= 3
end

# Before the pause age: not yet eligible, so the lag is still frozen despite the growing backlog
assert DT[:before_age].max <= 2, "compensated before pause_age, got max #{DT[:before_age].max}"
# After the pause age: eligible, so the lag is compensated and reflects the backlog
assert DT[:after_age].max >= 15, "not compensated after pause_age, got max #{DT[:after_age].max}"
