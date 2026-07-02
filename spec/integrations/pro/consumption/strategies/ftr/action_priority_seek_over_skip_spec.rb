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

# `:seek` has priority over `:skip`. A seeking filter and a skipping filter both apply: even though
# the skipping filter would otherwise just drop the batch, the higher-priority seek wins and the
# partition seeks (a `filtering.seek` event fires). The seek runs once (the listener disables it
# afterwards) so the run terminates instead of looping.

setup_karafka do |config|
  config.max_messages = 10
end

FilterBase = Karafka::Pro::Processing::ConsumerGroups::Filters::Base
Actions = Karafka::Pro::Processing::ConsumerGroups::Filters::Actions

class Listener
  def on_filtering_seek(_event)
    DT[:seeks] << true
    # Stop seeking after the first one so we do not loop forever seeking to the same offset
    Seeker.seeking = false
  end
end

Karafka.monitor.subscribe(Listener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:consumed] << message.offset }
  end
end

# Seeks back to the first offset of the batch, but only until the listener disables it
class Seeker < FilterBase
  class << self
    attr_accessor :seeking
  end

  self.seeking = true

  attr_reader :cursor

  def apply!(messages)
    @applied = false
    @cursor = nil
    return if messages.empty?
    return unless self.class.seeking

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

# Always applies and asks to skip - this must not suppress the seek above
class Skipper < FilterBase
  def apply!(messages)
    @applied = false
    return if messages.empty?

    messages.pop
    @applied = true
  end

  def applied?
    @applied
  end

  def action
    Actions.skip
  end

  def cursor
    nil
  end

  def timeout
    0
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter(->(*) { Seeker.new })
    filter(->(*) { Skipper.new })
  end
end

produced = false

start_karafka_and_wait_until do
  unless produced
    produce_many(DT.topic, DT.uuids(20))
    produced = true
  end

  DT[:seeks].size >= 1
end

# The seek won over the coexisting skip filter and was actually performed
assert(DT[:seeks].size >= 1, "seek must take priority over skip, but no seek was performed")
