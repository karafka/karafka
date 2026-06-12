# frozen_string_literal: true

# When subscribing to a topic that does not exist and allow.auto.create.topics is false,
# the consumer group join never completes. librdkafka cycles between "init" and
# "wait-metadata" indefinitely - it never reaches "steady".
#
# Both "init" and "wait-metadata" are pre-join states (the consumer has not yet issued
# a JoinGroup request), so stability tracking skips them. stability_ttl_exceeded does
# NOT fire, which means this stuck state goes undetected by stability_ttl.
#
# This is a known design boundary: stability_ttl targets consumers frozen in a mid-join
# state (e.g. stuck in "wait-assn" due to KAFKA-19862), not consumers that never start
# the join protocol because the topic is missing. This is NOT a false positive - the
# probe stays healthy (200) - but users should be aware of this scope limitation.

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

# librdkafka cycles "init" <-> "wait-metadata". Both are pre-join states that are excluded
# from stability tracking entirely - they never start or reset the timer, so
# stability_ttl_exceeded must not fire. Cycling in these states is outside the detection
# scope of stability_ttl; polling_ttl covers the case where the broker is unreachable.
assert DT[:bodies].none? { |body| JSON.parse(body)["errors"]["stability_ttl_exceeded"] },
  "stability_ttl_exceeded fired for a cycling consumer (non-existent topic, no auto-create). " \
  "join_states: #{DT[:join_states].uniq}"

assert DT[:probing].none? { |code| code == "500" },
  "Got HTTP 500 during non-existent topic cycling. join_states: #{DT[:join_states].uniq}"
