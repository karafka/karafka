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

# When LRJ + VP encounter errors, processing should retry correctly with VP collapse
# and eventually recover after the error condition clears.

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 100
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    collapsed?

    messages.each do |message|
      DT[0] << message.offset
    end

    if DT[:raised].empty?
      DT[:raised] << true
      raise StandardError
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

payloads = DT.uuids(5)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].uniq.size >= 5
end

# There should have been at least one error
assert DT[:errors].size >= 1
# All offsets should have been processed
assert_equal (0..4).to_a, DT[0].uniq.sort
