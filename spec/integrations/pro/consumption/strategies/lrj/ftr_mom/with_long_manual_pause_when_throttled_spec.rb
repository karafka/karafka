# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Karafka should not resume when manual pause is in use for LRJ.
# Karafka should not throttle (unless in idle which would indicate pause lift) when manually paused
# After un-pause, Karafka may do a full throttle if the previous throttling time did not finish
# Offsets should not be changed

setup_karafka do |config|
  config.max_messages = 50
  config.pause.timeout = 2_000
  config.pause.max_timeout = 2_000
  config.pause.with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    if messages.size < 2 && @not_first.nil?
      @not_first = true
      return
    end

    DT[:paused] << messages.first.offset

    pause(messages.first.offset, 2_000)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    manual_offset_management true
    throttling(limit: 5, interval: 5_000)
  end
end

produce_many(DT.topic, DT.uuids(200))

start_karafka_and_wait_until do
  DT[:paused].size >= 3
end

assert_equal 1, DT[:paused].uniq.size
assert_equal 0, fetch_next_offset
