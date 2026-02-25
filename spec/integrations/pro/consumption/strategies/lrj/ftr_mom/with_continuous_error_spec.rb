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

# Karafka should be able to recover from non-critical error when using lrj the same way as any
# normal consumer even if it happens often.
# We should retry from 0 because we do not commit offsets here at all
# We should not change the offset

class Listener
  def on_error_occurred(_)
    DT[:errors] << true
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true)

ERROR_FLOW = Array.new(100) { rand(2).zero? } + [true, false]

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError if ERROR_FLOW.pop

    messages.each { |message| DT[0] << message.offset }

    sleep 1

    produce_many(DT.topic, DT.uuids(5))
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    manual_offset_management true
    throttling(limit: 15, interval: 5_000)
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[0].size >= 25 && DT[:errors].size >= 5
end

assert DT[0].count(0) > 1
assert_equal 0, fetch_next_offset
