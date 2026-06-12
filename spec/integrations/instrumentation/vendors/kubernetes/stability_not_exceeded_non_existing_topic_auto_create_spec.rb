# frozen_string_literal: true

# When subscribing to a topic that does not exist and allow.auto.create.topics is true,
# the broker may auto-create the topic. However, the consumer group join may still take
# time to complete. Within a short observation window (well below stability_ttl), the
# process should remain healthy regardless of whether the consumer has reached "steady".
#
# Note: actual broker behavior (whether the topic gets auto-created and how quickly) depends
# on broker configuration (auto.create.topics.enable). In environments where auto-creation
# is disabled or slow, the consumer may stay in "init"/"wait-metadata" for the duration.
# Either way, stability_ttl (30s) is not exceeded in this short test window.

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
  DT[:probing].size >= 5
end

# Regardless of whether the consumer reached "steady" (depends on broker auto-create config),
# the stability_ttl (30s) is never exceeded in this 5-second observation window
assert DT[:bodies].none? { |body| JSON.parse(body)["errors"]["stability_ttl_exceeded"] },
  "Expected stability_ttl_exceeded to never be true within the short window"

assert DT[:probing].include?("200")
assert !DT[:probing].include?("500")
