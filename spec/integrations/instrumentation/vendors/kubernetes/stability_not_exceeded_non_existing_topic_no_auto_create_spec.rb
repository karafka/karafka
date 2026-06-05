# frozen_string_literal: true

# When subscribing to a topic that does not exist and allow.auto.create.topics is false,
# librdkafka cannot complete the consumer group join protocol. The cgrp.join_state cycles
# through "init" and "wait-metadata" indefinitely — it never reaches "steady". This IS
# genuinely stuck behavior: if it persists long enough, stability_ttl_exceeded will trigger.
#
# This test verifies that within a short observation window (well below stability_ttl),
# the process is still reported as healthy (stability_ttl not yet exceeded).

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
  DT[:probing].size >= 5
end

# The consumer stays non-steady when the topic doesn't exist and auto-creation is disabled.
# Without a topic to join, librdkafka cycles between "init" and "wait-metadata" indefinitely.
# Eventually (after stability_ttl ms) this would be reported as unhealthy — that is correct.
assert DT[:join_states].none? { |s| s == "steady" },
  "Expected consumer to stay non-steady for non-existent topic, got: #{DT[:join_states]}"

# Within the 5-second window (well below the 30-second stability_ttl), no unhealthy report
assert DT[:bodies].none? { |body| JSON.parse(body)["errors"]["stability_ttl_exceeded"] },
  "Expected stability_ttl_exceeded to never be true within the short window"

assert DT[:probing].include?("200")
assert !DT[:probing].include?("500")
