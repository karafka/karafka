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

# When VP is in collapsed mode (retrying after error) and shutdown is triggered,
# Karafka should shut down gracefully without hanging.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    if collapsed?
      DT[:collapsed] << true
      # Signal that we're in collapsed mode for the shutdown trigger
      sleep(0.5)
    else
      messages.each do |message|
        DT[:messages] << message.offset
      end

      # Always raise in VP mode to force collapse
      raise StandardError
    end
  end

  def shutdown
    DT[:shutdown] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(20))

Thread.new do
  sleep(0.1) until DT[:collapsed].size >= 1

  Process.kill("INT", Process.pid)
end

start_karafka_and_wait_until { false }

# Shutdown hooks should have been called
assert DT[:shutdown].size >= 1
# VP should have collapsed before shutdown
assert DT[:collapsed].size >= 1
