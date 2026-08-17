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

# Lag compensation refreshes every long-paused partition of a topic, not just one. Two partitions
# of the same topic are paused and both keep receiving data, exercising the batched end-offsets
# query (one request carrying both partitions) and the per-partition registry storage.

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

# Seed one message per partition so each gets consumed once and then paused
2.times { |partition| produce(DT.topic, DT.uuid, partition: partition) }

# The producer stops a few statistics emissions before the server, so it never outlives the
# closed producer on shutdown
Thread.new do
  sleep(0.1) until DT.key?(:paused_0) && DT.key?(:paused_1)

  loop do
    2.times { |partition| produce(DT.topic, DT.uuid, partition: partition) }
    sleep(0.3)

    break if DT[:emits].size >= 20
  end
end

start_karafka_and_wait_until do
  DT[:emits].size >= 25
end

# Both paused partitions must be compensated independently
assert DT[:lag_0].max >= 15, "partition 0 lag did not grow, max #{DT[:lag_0].max}"
assert DT[:lag_1].max >= 15, "partition 1 lag did not grow, max #{DT[:lag_1].max}"
