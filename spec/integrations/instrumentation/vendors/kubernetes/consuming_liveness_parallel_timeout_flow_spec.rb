# frozen_string_literal: true

# When consuming using multiple subscription groups and only one hangs, k8s listener should
# be able to detect that.

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

setup_karafka do |config|
  config.concurrency = 10
end

class FastConsumer < Karafka::BaseConsumer
  def consume; end
end

class SlowConsumer < Karafka::BaseConsumer
  def consume
    sleep(5)
  end
end

listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: '127.0.0.1',
  port: 9001,
  consuming_ttl: 2_000
)

Karafka.monitor.subscribe(listener)

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)
    uri = URI.parse('http://127.0.0.1:9001/')
    response = Net::HTTP.get_response(uri)
    DT[:probing] << response.code
  end
end

draw_routes do
  subscription_group :a do
    topic DT.topics[0] do
      consumer SlowConsumer
    end
  end

  subscription_group :b do
    topic DT.topics[1] do
      consumer FastConsumer
    end
  end
end

produce_many(DT.topics[0], DT.uuids(1))
produce_many(DT.topics[1], DT.uuids(1))

start_karafka_and_wait_until do
  DT[:probing].uniq.size >= 2
end

assert DT[:probing].include?('204')
assert DT[:probing].include?('500')
