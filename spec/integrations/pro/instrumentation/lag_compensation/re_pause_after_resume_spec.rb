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

# Resuming stops refreshing a partition (its last value is kept). This checks the partition is
# re-tracked and refreshed again on a SECOND pause: it is paused past the pause age (compensated),
# auto-resumes, then paused again past the pause age. The second compensation must reflect a fresh,
# higher end offset - proving the pause tracking re-arms after a resume rather than staying dropped.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed!(messages.last)

    # Two pause/resume cycles, then just drain (pause count tracked as an array size)
    return if DT[:pauses].size >= 2

    DT[:pauses] << true
    DT[:started] = true
    # Finite pause well past the pause age, so it compensates and then auto-resumes
    pause(messages.last.offset + 1, 8_000)
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  DT[:emits] << true
  phase = DT[:pauses].size

  event[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"
      next unless phase >= 1

      DT[:"lag_phase_#{phase}"] << partition_values["consumer_lag"]
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

# Keep producing across both pause cycles; producer stops a few emissions before the server
Thread.new do
  sleep(0.1) until DT.key?(:started)

  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(0.3)

    break if DT[:emits].size >= 40
  end
end

start_karafka_and_wait_until do
  DT[:emits].size >= 44
end

# Compensated during the first pause ...
assert DT[:lag_phase_1].max >= 15, "first pause not compensated, got max #{DT[:lag_phase_1].max}"
# ... and re-tracked and compensated again on the second pause, to a fresher (higher) value - so the
# tracking re-armed after the resume instead of staying dropped
assert DT[:lag_phase_2].max >= DT[:lag_phase_1].max + 8,
  "second pause not re-compensated fresh (phase1=#{DT[:lag_phase_1].max}, phase2=#{DT[:lag_phase_2].max})"
