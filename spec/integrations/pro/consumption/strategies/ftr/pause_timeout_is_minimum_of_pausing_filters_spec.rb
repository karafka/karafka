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

# When multiple filters resolve to `:pause` with different backoffs, the partition must pause for
# the MINIMUM of them: we pause for the shortest requested backoff, re-poll and re-apply, so a
# longer filter simply pauses again next cycle. A coexisting seeking filter reports a 0 timeout
# and must be ignored entirely.
#
# This single case pins down the exact combined pause and distinguishes every variant:
#   - correct (minimum of pausing filters, seek ignored) -> 2000
#   - taking the maximum of the pausing filters          -> 5000
#   - taking the minimum across ALL filters (seek's 0)   -> 0
#
# It also exercises both filter styles end to end: one filter declares its action via the new
# `Actions.pause` helper, the other returns the raw `:pause` symbol - both must behave identically.

setup_karafka

Actions = Karafka::Pro::Processing::ConsumerGroups::Filters::Actions

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:consumed] << message.offset }
  end
end

# Base for the two pausing filters below - each pops one message so both apply on a full batch
class BasePause < Karafka::Pro::Processing::ConsumerGroups::Filters::Base
  attr_reader :cursor

  def apply!(messages)
    @applied = false
    @cursor = nil
    return if messages.empty?

    @cursor = messages.last
    messages.pop
    @applied = true
  end

  def applied?
    @applied
  end
end

# Shorter backoff, declares the action via the Actions helper (the recommended new API)
class ShortBackoff < BasePause
  def action
    applied? ? Actions.pause : Actions.skip
  end

  def timeout
    2_000
  end
end

# Longer backoff, returns the raw legacy symbol - must still interoperate
class LongBackoff < BasePause
  def action
    applied? ? :pause : :skip
  end

  def timeout
    5_000
  end
end

# Seeks and reports a 0 timeout (like the built-in throttler/delayer when seeking). Its 0 must not
# participate in the pause timeout at all.
class Seeker < BasePause
  def action
    applied? ? Actions.seek : Actions.skip
  end

  def timeout
    0
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter(->(*) { ShortBackoff.new })
    filter(->(*) { LongBackoff.new })
    filter(->(*) { Seeker.new })
  end
end

Karafka.monitor.subscribe("filtering.throttled") do |event|
  DT[:timeouts] << event[:timeout]
end

produced = false

start_karafka_and_wait_until do
  unless produced
    produce_many(DT.topic, DT.uuids(20))
    produced = true
  end

  DT[:timeouts].size >= 1
end

# Minimum of the pausing filters (2000 and 5000), with the seek filter's 0 ignored.
assert_equal([2_000], DT[:timeouts].uniq)
