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

# When using a pattern subscription that matches no existing topics, this test observes
# the actual librdkafka cgrp.join_state behaviour over a window long enough for any
# stability_ttl to fire.
#
# We use a short stability_ttl (5 s) and observe for 20 s. If librdkafka never reaches
# "steady" when no topics match the regex, stability_ttl_exceeded will fire and we get
# HTTP 500 - confirming a false-positive risk that needs to be documented or mitigated.
# If "steady" is reached (empty assignment), HTTP stays 200 throughout - no false positive.

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

# If librdkafka reaches "steady" with an empty assignment (no matching topics), the
# stability timer never starts and the probe stays healthy throughout - no false positive.
#
# If librdkafka stays non-steady cycling through "init"/"wait-metadata" indefinitely,
# stability_ttl (5 s) fires and we see HTTP 500 - false positive confirmed.
reached_steady = DT[:join_states].include?("steady")
stability_fired = DT[:bodies].any? { |body| JSON.parse(body)["errors"]["stability_ttl_exceeded"] }

assert reached_steady,
  "Expected librdkafka to reach steady with empty assignment for no-match pattern, " \
  "but only saw: #{DT[:join_states].uniq}. " \
  "stability_ttl_exceeded fired: #{stability_fired}. " \
  "This confirms a false-positive risk - stability_ttl must not be used with pattern " \
  "subscriptions when no topics match, or the feature needs to skip pattern-based groups."

assert !stability_fired,
  "stability_ttl_exceeded fired for a pattern subscription with no matching topics - " \
  "this is a false positive. join_states seen: #{DT[:join_states].uniq}"
