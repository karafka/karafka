# frozen_string_literal: true

# The Kubernetes liveness listener should work with share groups (KIP-932): when the share
# consumer polls and consumes (even with a consumer error on the way), the probe should report
# healthy without any of the TTLs being exceeded.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/liveness_listener"

# Raise consumer error, just to make sure this does not impact liveness
setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    unless @raised
      @raised = true
      raise StandardError
    end

    messages.each { |message| mark_as_accepted(message) }

    DT[0] << true
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: "127.0.0.1",
  port: 9025
)

Karafka.monitor.subscribe(listener)

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)

    response = Net::HTTP.new("127.0.0.1", 9025).request(Net::HTTP::Get.new("/"))

    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(0) && DT[:probing].size >= 5
end

assert DT[:probing].include?("200"), DT[:bodies].last
assert !DT[:probing].include?("500"), DT[:bodies].last

last = JSON.parse(DT[:bodies].last)

assert_equal "healthy", last["status"]
assert_equal false, last["errors"]["polling_ttl_exceeded"]
assert_equal false, last["errors"]["consumption_ttl_exceeded"]
assert_equal false, last["errors"]["stability_ttl_exceeded"]
assert_equal false, last["errors"]["unrecoverable"]
