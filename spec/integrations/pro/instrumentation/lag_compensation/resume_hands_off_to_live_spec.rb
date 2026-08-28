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

# On resume the refreshed values are kept (not dropped), so the compensator hands over to the live
# statistics only once librdkafka post-resume fetches catch up. This spec drives the full
# lifecycle: a partition is paused past the pause age (lag gets compensated), then auto-resumes and
# drains the backlog, and the reported lag returns to zero without the backlog going unaccounted.
# The precise "no snap back to the frozen value on resume" is pinned deterministically in the unit
# specs; here we assert the robust end-to-end invariant.

setup_karafka do |config|
  config.max_messages = 10
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

BACKLOG = 20

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:consumed] << message.offset }
    mark_as_consumed!(messages.last)

    return if DT.key?(:paused)

    # Pause long enough to cross the pause age (compensation kicks in), then auto-resume so the
    # backlog produced meanwhile gets drained
    pause(messages.last.offset + 1, 8_000)
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

# Produce the whole backlog while paused, then stop - so after resume there is a fixed amount to
# drain and the lag can settle back to zero
Thread.new do
  sleep(0.1) until DT.key?(:paused)

  produce_many(DT.topic, DT.uuids(BACKLOG))
end

start_karafka_and_wait_until do
  # First message plus the whole backlog consumed => resumed and fully drained, and enough
  # statistics samples gathered to see the lag settle
  DT[:consumed].uniq.size >= BACKLOG + 1 && DT[:lags].size >= 22
end

# Compensation grew the lag to reflect the backlog while the partition was paused ...
assert DT[:lags].max >= 15, "expected compensated lag while paused, got max #{DT[:lags].max}"
# ... and once resumed and drained, the reported lag settles back to ~zero (live stats took over)
assert DT[:lags].last(3).max <= 2, "expected lag to drain after resume, tail #{DT[:lags].last(5)}"
