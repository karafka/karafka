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

# Each paused partition must be compensated with ITS OWN end offset - the batched query resolves
# many partitions at once and stores them per partition, so a mix-up (one partition's high watermark
# applied to another) would be a real risk. Two partitions of one topic are paused and then fed at
# very different rates: partition 0 gets a large backlog, partition 1 a small one. The compensated
# lags must stay far apart and each reflect its own partition, not a blended or swapped value.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

FAST = 30
SLOW = 6

class Consumer < Karafka::BaseConsumer
  def consume
    partition = messages.metadata.partition
    mark_as_consumed!(messages.last)

    return if DT.key?(:"paused_#{partition}")

    pause(messages.last.offset, 1_000_000)
    DT[:"paused_#{partition}"] = true
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

# One seed per partition so each gets consumed once and then paused
2.times { |partition| produce(DT.topic, DT.uuid, partition: partition) }

# Once both are paused, feed partition 0 heavily and partition 1 lightly - a single burst each, so
# the backlogs are fixed and clearly different
Thread.new do
  sleep(0.1) until DT.key?(:paused_0) && DT.key?(:paused_1)

  FAST.times { produce(DT.topic, DT.uuid, partition: 0) }
  SLOW.times { produce(DT.topic, DT.uuid, partition: 1) }

  DT[:produced] = true
end

start_karafka_and_wait_until do
  compensated = DT[:lag_0].max.to_i >= 20 && DT[:lag_1].max.to_i >= 2
  compensated || (DT.key?(:produced) && DT[:emits].size >= 45)
end

# Partition 0 is compensated to its large backlog ...
assert DT[:lag_0].max >= 20, "partition 0 not compensated to its backlog, got max #{DT[:lag_0].max}"
# ... partition 1 to its own small backlog (compensated, but small - not blended up with partition 0)
assert DT[:lag_1].max.between?(2, 12), "partition 1 lag looks mixed with another partition, got max #{DT[:lag_1].max}"
# ... and the two stay far apart, so no partition's high watermark leaked into the other
assert DT[:lag_0].max - DT[:lag_1].max >= 15, "partitions not clearly separated (0=#{DT[:lag_0].max}, 1=#{DT[:lag_1].max})"
