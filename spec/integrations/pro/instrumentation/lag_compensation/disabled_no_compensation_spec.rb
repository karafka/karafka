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

# The feature is opt-in even under Pro. With the interval left at its default of 0, the refresher is
# never subscribed and the compensator is a no-op, so a long-paused partition keeps reporting the
# frozen lag - identical to the base behaviour in
# spec/integrations/instrumentation/statistics_frozen_lag_on_paused.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  # Explicitly disabled (this is also the default). The pause age is low and the run outlasts it,
  # so the partition really does stay paused past the threshold - the only reason it is not
  # compensated is that the feature is off. Flipping interval to a non-zero value must therefore
  # break this spec, otherwise the assertion would pass for the wrong reason (never crossing the
  # pause age).
  config.internal.statistics.consumer_groups.lag_compensation.interval = 0
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

# Produce a large backlog while paused: with compensation off the reported lag must still stay
# frozen despite all of these unconsumed messages
Thread.new do
  sleep(0.1) until DT.key?(:paused)

  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(0.3)

    break if DT[:lags].size >= 20
  end
end

start_karafka_and_wait_until do
  DT[:lags].size >= 25
end

# Frozen: the disabled feature never refreshes the stale statistics
assert DT[:lags].max <= 2, "expected frozen lag with compensation disabled, got max #{DT[:lags].max}"
