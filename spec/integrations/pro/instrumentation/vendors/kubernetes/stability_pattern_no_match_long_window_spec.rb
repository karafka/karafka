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

# When using a pattern subscription that matches no existing topics, librdkafka stays in
# the "init" join_state indefinitely (it never issues a JoinGroup request when there are
# no matching topics). Because the stability check skips "init" (it is not a stuck-join
# state), stability_ttl_exceeded must never fire - no false positive.
#
# This test uses a short stability_ttl (5 s) over a 20 s window to confirm that.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/liveness_listener"

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"statistics.interval.ms"] = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

# Pattern guaranteed to match no existing topics
draw_routes(create_topics: false) do
  pattern(/nonexistent_isolated_no_topic_should_ever_match_this_long_window/) do
    consumer Consumer
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: "127.0.0.1",
  port: 9019,
  stability_ttl: 5_000
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
    uri = URI.parse("http://127.0.0.1:9019/")
    response = Net::HTTP.get_response(uri)
    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

start_karafka_and_wait_until do
  DT[:probing].size >= 20
end

# librdkafka stays in "init" when no topics match the regex. The stability check skips
# "init" entirely, so stability_ttl_exceeded must never fire.
stability_fired = DT[:bodies].any? { |body| JSON.parse(body)["errors"]["stability_ttl_exceeded"] }

assert !stability_fired,
  "stability_ttl_exceeded fired for a pattern subscription with no matching topics - " \
  "this is a false positive. join_states seen: #{DT[:join_states].uniq}"

assert DT[:probing].none? { |code| code == "500" },
  "Got HTTP 500 during pattern no-match observation. join_states: #{DT[:join_states].uniq}"
