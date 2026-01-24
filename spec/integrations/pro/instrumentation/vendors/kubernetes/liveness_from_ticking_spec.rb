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

# When we only tick, it should be considered good as long as within time boundaries

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

setup_karafka

class Consumer < Karafka::BaseConsumer
  def tick
    @ticks ||= 0
    @ticks += 1

    sleep(5) if @ticks == 1

    DT[0] << true if @ticks == 10
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: '127.0.0.1',
  port: 9006,
  consuming_ttl: 1_000
)

Karafka.monitor.subscribe(listener)

raw_flows = +''

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)

    req = Net::HTTP::Get.new('/')
    client = Net::HTTP.new('127.0.0.1', 9006)
    client.set_debug_output(raw_flows)
    response = client.request(req)

    DT[:probing] << response.code

    next if response.code == '200'

    DT[:bodies] << response.body
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic interval: 100
  end
end

start_karafka_and_wait_until do
  DT.key?(0)
end

assert DT[:probing].include?('200')
# 500 should happen as we tuned it aggressively and it should react to "hanging" tick
assert DT[:probing].include?('500')

last = JSON.parse(DT[:bodies].last)

assert_equal 'unhealthy', last['status']
assert last.key?('timestamp')
assert_equal 9006, last['port']
assert_equal Process.pid, last['process_id']
assert_equal false, last['errors']['polling_ttl_exceeded']
assert_equal true, last['errors']['consumption_ttl_exceeded']
assert_equal false, last['errors']['unrecoverable']
