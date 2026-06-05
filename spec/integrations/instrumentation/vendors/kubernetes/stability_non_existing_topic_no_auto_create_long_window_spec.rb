# frozen_string_literal: true

# When subscribing to a topic that does not exist and allow.auto.create.topics is false,
# the consumer group join never completes. librdkafka cycles between "init" and
# "wait-metadata" indefinitely - it never reaches "steady".
#
# Because the stability timer resets on every state transition, stability_ttl_exceeded
# does NOT fire even though the consumer is genuinely stuck. This is a known design
# boundary: stability_ttl detects consumers frozen in a single non-steady state (e.g.
# stuck in "wait-assn" due to a broker-side hang like KAFKA-19862) but not consumers
# that cycle between non-steady states fast enough to keep the timer from accumulating.
#
# This is NOT a false positive - the probe stays healthy (200) - but it means
# stability_ttl gives no signal for non-existent-topic situations. Users relying on
# stability_ttl should be aware that the feature targets single-state freezes, not
# cycling states.

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
  topic "nonexistent-noautocreate-#{DT.topic}" do
    consumer Consumer
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: "127.0.0.1",
  port: 9021,
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
    uri = URI.parse("http://127.0.0.1:9021/")
    response = Net::HTTP.get_response(uri)
    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

start_karafka_and_wait_until do
  DT[:probing].size >= 20
end

# The consumer is genuinely stuck - topic does not exist and cannot be auto-created.
assert DT[:join_states].none? { |s| s == "steady" },
  "Expected consumer to never reach steady for non-existent topic (no auto-create), " \
  "got: #{DT[:join_states].uniq}"

# librdkafka cycles "init" <-> "wait-metadata", resetting the stability timer on each
# transition. stability_ttl_exceeded must not fire (no false positive), but also gives
# no signal here - cycling states are outside the detection scope of stability_ttl.
assert DT[:bodies].none? { |body| JSON.parse(body)["errors"]["stability_ttl_exceeded"] },
  "stability_ttl_exceeded fired for a cycling consumer (non-existent topic, no auto-create). " \
  "join_states: #{DT[:join_states].uniq}"

assert DT[:probing].none? { |code| code == "500" },
  "Got HTTP 500 during non-existent topic cycling. join_states: #{DT[:join_states].uniq}"
