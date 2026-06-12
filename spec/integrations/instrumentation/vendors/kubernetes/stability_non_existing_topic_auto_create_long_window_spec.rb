# frozen_string_literal: true

# When subscribing to a topic that does not exist and allow.auto.create.topics is true,
# librdkafka cycles between "init" and "wait-metadata" until the topic is auto-created.
# Both states are pre-join (the consumer has not yet issued a JoinGroup request), so
# stability tracking skips them entirely - stability_ttl_exceeded must never fire.
#
# This test verifies no false positive over a 20 s window with a 5 s stability_ttl.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/liveness_listener"

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"allow.auto.create.topics"] = true
  config.kafka[:"statistics.interval.ms"] = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(create_topics: false) do
  topic "nonexistent-autocreate-#{DT.topic}" do
    consumer Consumer
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: "127.0.0.1",
  port: 9020,
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
    uri = URI.parse("http://127.0.0.1:9020/")
    response = Net::HTTP.get_response(uri)
    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

start_karafka_and_wait_until do
  DT[:probing].size >= 20
end

# The consumer may cycle between "init" and "wait-metadata" while waiting for the topic
# to be auto-created. Each transition resets the stability timer, so stability_ttl_exceeded
# must never fire regardless of how long the cycling goes on.
assert DT[:bodies].none? { |body| JSON.parse(body)["errors"]["stability_ttl_exceeded"] },
  "stability_ttl_exceeded fired for a cycling consumer awaiting auto-create - " \
  "this is a false positive. join_states seen: #{DT[:join_states].uniq}"

assert DT[:probing].none? { |code| code == "500" },
  "Got HTTP 500 during auto-create wait. join_states: #{DT[:join_states].uniq}"
