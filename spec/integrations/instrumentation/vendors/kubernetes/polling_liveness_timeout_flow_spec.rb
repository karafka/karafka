# frozen_string_literal: true

# When the polling happens less frequently than expected, we should get a timeout indication
# out of the probing

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(2)
    DT[0] << true
  end
end

listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: '127.0.0.1',
  port: 9005,
  polling_ttl: 1_000
)

Karafka.monitor.subscribe(listener)

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)
    uri = URI.parse('http://127.0.0.1:9005/')
    response = Net::HTTP.get_response(uri)
    DT[:probing] << response.code
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(0)
end

assert DT[:probing].include?('204')
assert DT[:probing].include?('500')
