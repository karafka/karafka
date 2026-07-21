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

# A partition only qualifies for compensation after staying paused for at least the pause age.
# With a high pause age and a run shorter than it, the partition is paused the whole time yet never
# long enough to qualify, so its lag must stay frozen despite a growing backlog. This guards the
# pause_age threshold in long_paused_for (a partition that is merely paused is not enough).

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  # High threshold: the spec runs for far less than this, so the pause never qualifies
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 30_000
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

# Produce a backlog while paused; it must not surface as lag because the pause age is never reached
Thread.new do
  sleep(0.1) until DT.key?(:paused)

  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(0.3)

    break if DT[:lags].size >= 15
  end
end

# ~9s of samples, an order of magnitude below the 30s pause age
start_karafka_and_wait_until do
  DT[:lags].size >= 18
end

# Paused but never long enough: the lag stays frozen, compensation does not kick in
assert DT[:lags].max <= 2, "expected no compensation below pause_age, got max #{DT[:lags].max}"
