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

# When using a pattern subscription that matches no existing topics, librdkafka still
# completes the consumer group join with an empty partition assignment. The
# cgrp.join_state should reach "steady" and the rebalance_ttl should never be exceeded.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/liveness_listener"

setup_karafka do |config|
  config.kafka[:"statistics.interval.ms"] = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

# Use a pattern that is guaranteed to match no existing topics
draw_routes(create_topics: false) do
  pattern(/nonexistent_isolated_no_topic_should_ever_match_this/) do
    consumer Consumer
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: "127.0.0.1",
  port: 9018,
  rebalance_ttl: 30_000
)

Karafka.monitor.subscribe(listener)

Karafka.monitor.subscribe("statistics.emitted") do |event|
  cgrp = event[:statistics]["cgrp"]
  DT[:join_states] << cgrp["join_state"] if cgrp
end

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5)

  until Karafka::App.stopping?
    sleep(1)
    uri = URI.parse("http://127.0.0.1:9018/")
    response = Net::HTTP.get_response(uri)
    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

start_karafka_and_wait_until do
  DT[:join_states].size >= 5
end

# librdkafka completes the group join with an empty assignment when no topics match
# the regex pattern - the consumer group join is independent of whether any topics match
assert DT[:join_states].last(3).all? { |s| s == "steady" },
  "Expected last join_states to be steady, got: #{DT[:join_states].last(3)}"

assert DT[:bodies].none? { |body| JSON.parse(body)["errors"]["rebalance_ttl_exceeded"] },
  "Expected rebalance_ttl_exceeded to never be true"

assert DT[:probing].include?("200")
assert !DT[:probing].include?("500")
