# frozen_string_literal: true

# When subscribing to a topic that does not exist and allow.auto.create.topics is false,
# librdkafka still completes the consumer group join protocol with an empty partition
# assignment. The cgrp.join_state should reach "steady" and remain there, meaning the
# stability_ttl should never be exceeded despite the UNKNOWN_TOPIC_OR_PART poll errors.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/liveness_listener"

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"allow.auto.create.topics"] = false
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
  port: 9016,
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
    uri = URI.parse("http://127.0.0.1:9016/")
    response = Net::HTTP.get_response(uri)
    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

start_karafka_and_wait_until do
  DT[:join_states].size >= 5
end

# librdkafka completes the join protocol with an empty assignment even when the topic
# does not exist - the consumer group join and topic partition existence are independent
assert DT[:join_states].last(3).all? { |s| s == "steady" },
  "Expected last join_states to be steady, got: #{DT[:join_states].last(3)}"

# The stability_ttl should never be exceeded
assert DT[:bodies].none? { |body| JSON.parse(body)["errors"]["stability_ttl_exceeded"] },
  "Expected stability_ttl_exceeded to never be true"

assert DT[:probing].include?("200")
assert !DT[:probing].include?("500")
