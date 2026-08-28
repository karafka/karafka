# frozen_string_literal: true

# The readiness probe reports ready only once EVERY active subscription group has polled at least
# once. With several consumer groups (hence several subscription groups) subscribed, the final
# readiness body must reflect that all of them have polled: `polled_subscription_groups` and
# `expected_subscription_groups` both equal the number of subscription groups.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/readiness_listener"

setup_karafka

# Number of consumer groups (and thus subscription groups) that all have to poll before we are ready
GROUPS_COUNT = 5

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << true
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::ReadinessListener.new(
  hostname: "127.0.0.1",
  port: 9024
)

Karafka.monitor.subscribe(listener)

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)

    uri = URI.parse("http://127.0.0.1:9024/")
    response = Net::HTTP.get_response(uri)

    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

draw_routes do
  GROUPS_COUNT.times do |i|
    consumer_group "group#{i}" do
      topic DT.topic do
        consumer Consumer
      end
    end
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[:consumed].size >= GROUPS_COUNT
end

assert DT[:probing].include?("200")

# Assert on a ready snapshot: the very last probe could race the shutdown transition, so we pick the
# last body that reported healthy.
ready = DT[:bodies].map { |body| JSON.parse(body) }.select { |b| b["status"] == "healthy" }
last = ready.last

assert !last.nil?
assert_equal "healthy", last["status"]
assert_equal true, last["ready"]
assert_equal 9024, last["port"]
assert_equal Process.pid, last["process_id"]
# All subscription groups have to be both expected and polled for readiness to latch.
assert_equal GROUPS_COUNT, last["expected_subscription_groups"]
assert_equal GROUPS_COUNT, last["polled_subscription_groups"]
