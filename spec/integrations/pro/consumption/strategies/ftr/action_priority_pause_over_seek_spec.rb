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

# When filters resolve to different actions, `:pause` has the highest priority. Here a pausing
# filter and a seeking filter both apply on every batch: the partition must pause (a
# `filtering.throttled` event) and must NOT seek (`filtering.seek` never fires), even though the
# seeking filter offers a cursor it would otherwise seek to.

setup_karafka

FilterBase = Karafka::Pro::Processing::ConsumerGroups::Filters::Base
Actions = Karafka::Pro::Processing::ConsumerGroups::Filters::Actions

class Listener
  def on_filtering_seek(_event)
    DT[:seeks] << true
  end

  def on_filtering_throttled(_event)
    DT[:throttled] << true
  end
end

Karafka.monitor.subscribe(Listener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:consumed] << message.offset }
  end
end

# Pops one message and asks to pause with a fixed backoff
class Pauser < FilterBase
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

  def action
    applied? ? Actions.pause : Actions.skip
  end

  def timeout
    1_000
  end
end

# Pops one message and asks to seek back to the first offset. This seek must be suppressed by the
# higher-priority pause above.
class Seeker < FilterBase
  attr_reader :cursor

  def apply!(messages)
    @applied = false
    @cursor = nil
    return if messages.empty?

    @cursor = messages.first
    messages.pop
    @applied = true
  end

  def applied?
    @applied
  end

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
    filter(->(*) { Pauser.new })
    filter(->(*) { Seeker.new })
  end
end

produced = false

start_karafka_and_wait_until do
  unless produced
    produce_many(DT.topic, DT.uuids(20))
    produced = true
  end

  # Wait for a couple of pause cycles so we can be confident no seek ever slips through
  DT[:throttled].size >= 2
end

assert DT[:throttled].size >= 2, "expected the partition to pause (throttled) on the pause action"
assert(
  DT[:seeks].empty?,
  "pause must take priority over seek, but a seek was performed (#{DT[:seeks].size})"
)
