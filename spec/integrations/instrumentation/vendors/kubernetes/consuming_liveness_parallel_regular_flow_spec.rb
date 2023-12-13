# frozen_string_literal: true

# When consuming using multiple subscription groups and all of them are within time limits,
# we should never get 500

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: '127.0.0.1',
  port: 9000,
  consuming_ttl: 2_000
)

Karafka.monitor.subscribe(listener)

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)
    uri = URI.parse('http://127.0.0.1:9000/')
    response = Net::HTTP.get_response(uri)
    DT[:probing] << response.code
  end
end

draw_routes do
  subscription_group :a do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  subscription_group :b do
    topic DT.topics[1] do
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  if DT[0].count >= 20
    true
  else
    sleep(0.1)
    produce_many(DT.topics[0], DT.uuids(1))
    produce_many(DT.topics[1], DT.uuids(1))
    false
  end
end

assert DT[:probing].include?('204')
assert !DT[:probing].include?('500')
