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

# Compensation only touches paused partitions. With partition 0 paused forever and partition 1
# actively consumed, the paused one's lag grows (compensated) while the active one keeps reporting
# its real, near-zero live lag - the refresher never tracks it and the compensator never overlays
# it.

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

    DT[:"consumed_#{partition}"] << true

    return unless partition.zero?
    return if DT.key?(:paused_0)

    pause(messages.last.offset, 1_000_000)
    DT[:paused_0] = true
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  DT[:emits] << true

  event[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:"lag_#{partition_name}"] << partition_values["consumer_lag"]
    end
  end
end

draw_topics do
  topic(DT.topic) { partitions(2) }
end

draw_routes(Consumer)

2.times { |partition| produce(DT.topic, DT.uuid, partition: partition) }

# The producer stops a few statistics emissions before the server, so it never outlives the
# closed producer on shutdown
Thread.new do
  sleep(0.1) until DT.key?(:paused_0)

  loop do
    2.times { |partition| produce(DT.topic, DT.uuid, partition: partition) }
    sleep(0.3)

    break if DT[:emits].size >= 20
  end
end

start_karafka_and_wait_until do
  DT[:emits].size >= 25
end

# Paused partition is compensated to reflect the produced backlog
assert DT[:lag_0].max >= 15, "paused partition 0 lag did not grow, max #{DT[:lag_0].max}"
# Active partition keeps up on its own; its live lag is never overlaid with a stale value
assert DT[:lag_1].max <= 5, "active partition 1 lag was unexpectedly high, max #{DT[:lag_1].max}"
