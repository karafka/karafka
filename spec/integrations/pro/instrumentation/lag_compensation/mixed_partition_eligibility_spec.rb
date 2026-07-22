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

# Eligibility for compensation is decided per partition, not per client. Two partitions of one topic
# are paused at different moments: partition 0 early (so it crosses the pause age) and partition 1
# late. While partition 0 is already compensated, partition 1 - still younger than the pause age -
# must remain frozen even though it also has a backlog. This guards the per-partition age filter in
# `long_paused_for`.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    partition = messages.metadata.partition
    mark_as_consumed!(messages.last)

    return if DT.key?(:"paused_#{partition}")

    DT[:"paused_at_#{partition}"] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    pause(messages.last.offset, 1_000_000)
    DT[:"paused_#{partition}"] = true
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  DT[:emits] << true

  event[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      lag = partition_values["consumer_lag"]

      case partition_name
      when "0"
        DT[:lag_0] << lag
      when "1"
        # Only sample partition 1 while it is still younger than the pause age
        next unless DT.key?(:paused_at_1)

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - DT[:paused_at_1]
        DT[:lag_1_young] << lag if elapsed < 4
      end
    end
  end
end

draw_topics do
  topic(DT.topic) { partitions(2) }
end

draw_routes(Consumer)

# Partition 0 is seeded (and paused) right away. Both producers stop a few statistics emissions
# before the server does, so neither outlives the closed producer on shutdown.
produce(DT.topic, DT.uuid, partition: 0)

Thread.new do
  sleep(0.1) until DT.key?(:paused_0)

  loop do
    produce(DT.topic, DT.uuid, partition: 0)
    sleep(0.3)

    break if DT[:emits].size >= 22
  end
end

# Partition 1 is seeded (and paused) only later, so it stays younger than the pause age for the
# window in which partition 0 is already eligible
Thread.new do
  sleep(0.1) until DT[:emits].size >= 10

  produce(DT.topic, DT.uuid, partition: 1)
  sleep(0.1) until DT.key?(:paused_1)

  loop do
    produce(DT.topic, DT.uuid, partition: 1)
    sleep(0.3)

    break if DT[:emits].size >= 22
  end
end

start_karafka_and_wait_until do
  DT[:emits].size >= 26
end

# The old pause is compensated ...
assert DT[:lag_0].max >= 15, "long-paused partition 0 not compensated, got max #{DT[:lag_0].max}"
# ... while the young one stays frozen despite its own backlog (not yet eligible)
assert DT[:lag_1_young].max <= 2, "partition 1 compensated before pause_age, got max #{DT[:lag_1_young].max}"
