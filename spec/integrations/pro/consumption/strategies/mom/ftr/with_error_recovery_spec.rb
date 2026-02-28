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

# When MoM + FTR consumer encounters an error, it should recover via retry and process
# all messages. Since MoM is enabled, offsets should not be auto-committed.

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    if DT[:raised].empty?
      DT[:raised] << true
      raise StandardError
    end

    messages.each do |message|
      DT[:offsets] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    throttling(limit: 100, interval: 1_000)
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:offsets].size >= 20
end

# All offsets should be processed in order
assert_equal (0..19).to_a, DT[:offsets].uniq.sort
# There should have been at least one error
assert DT[:errors].size >= 1
# Since we didn't mark any offsets, the committed offset should be 0
assert_equal 0, fetch_next_offset
