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

# When an LRJ consumer is mid-processing (in a sleep/work loop) when shutdown signal arrives,
# it should detect the stopping state and exit cleanly.

setup_karafka do |config|
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    loop do
      break if Karafka::App.stopping?

      DT[:ticks] << true

      sleep(0.1)
    end

    DT[:aware] << true
  end

  def shutdown
    DT[:shutdown] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(10))

Thread.new do
  sleep(0.1) until DT[:ticks].size >= 5

  Process.kill("INT", Process.pid)
end

start_karafka_and_wait_until { false }

# Consumer should have detected stopping state
assert_equal [true], DT[:aware]
# Shutdown hook should have been called
assert_equal [true], DT[:shutdown]
# Consumer should have been running for a while before shutdown
assert DT[:ticks].size >= 5
