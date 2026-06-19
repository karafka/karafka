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

# F16: `FiltersApplier#action` resolves to `:pause` if ANY applied filter wants to pause, but the
# combined `#timeout` used to take the MINIMUM across all applied filters. A filter that resolved to
# `:seek` reports a `0` timeout (the built-in throttler/delayer do this on seek), so combining it
# with a pausing filter produced action `:pause` with timeout `min(5000, 0) == 0`. The partition
# then paused with timeout 0, expired immediately and busy-spun, defeating the backoff.
#
# Reproduced with two coexisting filters on one topic: a pausing filter requesting a 5s backoff and
# a seeking filter reporting a 0 timeout. The resolved action is `:pause`; we capture the pause
# duration from the `filtering.throttled` event. On master it is 0 (collapsed); with the fix it is
# the pausing filter's 5000 (the seek filter's 0 no longer participates).

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:consumed] << message.offset }
  end
end

# Always wants to pause with a fixed, non-zero backoff
class Backoff < Karafka::Pro::Processing::ConsumerGroups::Filters::Base
  attr_reader :cursor

  def apply!(messages)
    @applied = false
    @cursor = nil
    return if messages.empty?

    @cursor = messages.last
    messages.pop
    @applied = true
  end

  def action
    applied? ? :pause : :skip
  end

  def applied?
    @applied
  end

  def timeout
    5_000
  end
end

# Always wants to seek and - like the built-in throttler/delayer when seeking - reports a 0 timeout.
# That 0 must not collapse the pausing filter's backoff above.
class Seeker < Karafka::Pro::Processing::ConsumerGroups::Filters::Base
  attr_reader :cursor

  def apply!(messages)
    @applied = false
    @cursor = nil
    return if messages.empty?

    @cursor = messages.last
    messages.pop
    @applied = true
  end

  def action
    applied? ? :seek : :skip
  end

  def applied?
    @applied
  end

  def timeout
    0
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter(->(*) { Backoff.new })
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

# The pause must honor the pausing filter's backoff (5000) and not collapse to 0 because of the
# coexisting seek filter's 0 timeout.
assert_equal([5_000], DT[:timeouts].uniq)
