# frozen_string_literal: true

# When Karafka downscales the connections as part of resources management, liveness should be as
# the downscaled threads should deregister themselves.

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

setup_karafka do |config|
  c_klass = config.internal.connection.conductor.class
  m_klass = config.internal.connection.manager.class

  config.internal.connection.conductor = c_klass.new(1_000)
  config.internal.connection.manager = m_klass.new(1_000)
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def tick; end
end

listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: '127.0.0.1',
  port: 9011,
  polling_ttl: 2_000
)

Karafka.monitor.subscribe(listener)

raw_flows = +''

Karafka.monitor.subscribe('connection.listener.stopped') do
  DT[:stopped] = true
end

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5)

  until Karafka::App.stopping?
    sleep(0.1)

    req = Net::HTTP::Get.new('/')
    client = Net::HTTP.new('127.0.0.1', 9011)
    client.set_debug_output(raw_flows)
    response = client.request(req)

    DT[:probing] << response.code
  end
end

draw_routes do
  subscription_group do
    multiplexing(min: 1, max: 2, boot: 2)

    topic DT.topic do
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  DT.key?(:stopped) && sleep(2)
end

assert DT[:probing].include?('204')
assert !DT[:probing].include?('500')
