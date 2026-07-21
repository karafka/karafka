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

# Refreshed values are dropped in bulk on a rebalance: a partition may no longer belong to the
# client after one, so its stored data must be evicted. This drives a real rebalance (a second
# consumer joins the group) while a partition is paused and compensated, and confirms the feature
# coexists with rebalancing - compensation happens, the revoke fires and the evict path runs
# without disrupting the running consumer. The eviction of the registry itself is pinned in the
# unit specs.

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
  event[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:lags] << partition_values["consumer_lag"]
    end
  end
end

Karafka::App.monitor.subscribe("rebalance.partitions_revoked") do |_event|
  DT[:revoked] = true
end

draw_topics do
  topic(DT.topic) { partitions(2) }
end

draw_routes(Consumer)

2.times { |partition| produce(DT.topic, DT.uuid, partition: partition) }

Thread.new do
  sleep(0.1) until DT.key?(:paused_0) && DT.key?(:paused_1)

  loop do
    2.times { |partition| produce(DT.topic, DT.uuid, partition: partition) }
    sleep(0.3)

    break if DT.key?(:revoked) || DT[:lags].size >= 60
  end
end

# Once compensation is clearly observed, a second consumer joins the same group and forces a
# rebalance, revoking partitions from the running consumer
Thread.new do
  sleep(0.1) until DT[:lags].max.to_i >= 15

  other = setup_rdkafka_consumer
  other.subscribe(DT.topic)
  # Poll a few times so the join (and therefore the rebalance) actually happens, then leave
  10.times { other.poll(1_000) }
  other.close
end

start_karafka_and_wait_until do
  DT[:lags].max.to_i >= 15 && DT.key?(:revoked)
end

# Compensation was active before the rebalance ...
assert DT[:lags].max >= 15, "expected compensation before the rebalance, got max #{DT[:lags].max}"
# ... and the rebalance revoke (which runs the eviction) fired while the feature was enabled
assert DT.key?(:revoked), "expected a rebalance to revoke partitions"
