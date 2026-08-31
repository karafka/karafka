# frozen_string_literal: true

# Once the consumer has started polling all of its subscription groups, the readiness probe should
# report ready (200) with a body describing how many groups have polled. This mirrors the liveness
# "all good" flow but for the readiness endpoint and its richer body.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/readiness_listener"

# Raise a consumer error, just to make sure this does not impact readiness. Readiness only tracks
# that polling has started (and that we are not draining), so a user error must not flip it.
setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    unless @raised
      @raised = true
      raise StandardError
    end

    DT[0] << true
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::ReadinessListener.new(
  hostname: "127.0.0.1",
  port: 9022
)

Karafka.monitor.subscribe(listener)

raw_flows = +""

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)

    req = Net::HTTP::Get.new("/")
    client = Net::HTTP.new("127.0.0.1", 9022)
    client.set_debug_output(raw_flows)
    response = client.request(req)

    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(0)
end

# Readiness has a legitimate "not ready yet" window before the first poll, so we only require that
# it did become ready (200) rather than asserting 500 never appeared.
assert DT[:probing].include?("200")

responses = raw_flows.split("\n").select { |line| line.start_with?("->") }

ok_index = responses.index { |line| line.include?(" 200 ") }

assert !ok_index.nil?
assert_equal '-> "HTTP/1.1 200 OK\r\n"', responses[ok_index], responses[ok_index]
assert_equal '-> "Content-Type: application/json\r\n"', responses[ok_index + 1], responses[ok_index + 1]

# Assert on a ready snapshot: the very last probe could race the shutdown transition, so we pick the
# last body that reported healthy.
ready = DT[:bodies].map { |body| JSON.parse(body) }.select { |b| b["status"] == "healthy" }
last = ready.last

assert !last.nil?
assert_equal "healthy", last["status"]
assert last.key?("timestamp")
assert_equal 9022, last["port"]
assert_equal Process.pid, last["process_id"]
assert_equal true, last["ready"]
assert_equal 1, last["polled_subscription_groups"]
assert_equal 1, last["expected_subscription_groups"]
