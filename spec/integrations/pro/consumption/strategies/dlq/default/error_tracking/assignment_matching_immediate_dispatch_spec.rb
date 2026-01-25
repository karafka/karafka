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

# Same trace id should be present when instrumenting errors and during the DLQ dispatch

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 10
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:traces] << event[:caller].errors_tracker.trace_id
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if DT[:traces].size < 10

      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 0,
      independent: true
    )
  end

  topic DT.topics[1] do
    active(false)
  end
end

produce_many(DT.topic, (0..99).to_a.map(&:to_s))

start_karafka_and_wait_until do
  DT[:traces].size >= 10
end

sleep(1)

dlq_traces = Karafka::Admin
  .read_topic(DT.topics[1], 0, 100)
  .map { |message| message.headers["source_trace_id"] }

assert_equal(
  DT[:traces],
  dlq_traces
)
