# frozen_string_literal: true

# When subscribing to a topic that does not exist and allow.auto.create.topics is true,
# the broker auto-creates the topic and the consumer receives an assignment. The
# cgrp.join_state should reach "steady" and the stability_ttl should never be exceeded.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/liveness_listener"

setup_karafka do |config|
  config.kafka[:"allow.auto.create.topics"] = true
  config.kafka[:"statistics.interval.ms"] = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(create_topics: false) do
  topic "nonexistent-#{DT.topic}" do
    consumer Consumer
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: "127.0.0.1",
  port: 9017,
  stability_ttl: 30_000
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
    uri = URI.parse("http://127.0.0.1:9017/")
    response = Net::HTTP.get_response(uri)
    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

start_karafka_and_wait_until do
  DT[:join_states].size >= 5
end

# The broker auto-creates the topic and the consumer group join completes normally
assert DT[:join_states].last(3).all? { |s| s == "steady" },
  "Expected last join_states to be steady, got: #{DT[:join_states].last(3)}"

assert DT[:bodies].none? { |body| JSON.parse(body)["errors"]["stability_ttl_exceeded"] },
  "Expected stability_ttl_exceeded to never be true"

assert DT[:probing].include?("200")
assert !DT[:probing].include?("500")
