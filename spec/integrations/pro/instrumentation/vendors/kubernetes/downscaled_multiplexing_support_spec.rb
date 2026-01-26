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

# When Karafka downscales the connections as part of resources management, liveness should be as
# the downscaled threads should deregister themselves.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/liveness_listener"

setup_karafka do |config|
  c_klass = config.internal.connection.conductor.class

  config.internal.connection.conductor = c_klass.new(1_000)
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def tick
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: "127.0.0.1",
  port: 9011,
  polling_ttl: 2_000
)

Karafka.monitor.subscribe(listener)

raw_flows = +""

Karafka.monitor.subscribe("connection.listener.stopped") do
  DT[:stopped] = true
end

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5)

  until Karafka::App.stopping?
    sleep(0.1)

    req = Net::HTTP::Get.new("/")
    client = Net::HTTP.new("127.0.0.1", 9011)
    client.set_debug_output(raw_flows)
    response = client.request(req)

    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

draw_routes do
  subscription_group do
    multiplexing(min: 1, max: 2, boot: 2, scale_delay: 1_000)

    topic DT.topic do
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  DT.key?(:stopped) && sleep(2)
end

assert DT[:probing].include?("200")
assert !DT[:probing].include?("500")

last = JSON.parse(DT[:bodies].last)

assert_equal "healthy", last["status"]
assert last.key?("timestamp")
assert_equal 9011, last["port"]
assert_equal Process.pid, last["process_id"]
assert_equal false, last["errors"]["polling_ttl_exceeded"]
assert_equal false, last["errors"]["consumption_ttl_exceeded"]
assert_equal false, last["errors"]["unrecoverable"]
