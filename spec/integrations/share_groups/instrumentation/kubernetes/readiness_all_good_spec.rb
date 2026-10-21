# frozen_string_literal: true

# The Kubernetes readiness listener should work with share groups (KIP-932): once the share
# consumer starts polling, the readiness probe should report ready (200) and healthy.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/readiness_listener"

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }

    DT[0] << true
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::ReadinessListener.new(
  hostname: "127.0.0.1",
  port: 9026
)

Karafka.monitor.subscribe(listener)

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)

    response = Net::HTTP.new("127.0.0.1", 9026).request(Net::HTTP::Get.new("/"))

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
  DT.key?(0) && DT[:probing].include?("200")
end

ready = DT[:bodies].map { |body| JSON.parse(body) }.select { |b| b["status"] == "healthy" }

assert !ready.empty?, DT[:bodies]
assert_equal 9026, ready.last["port"]
