# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we only tick, it should be considered good as long as within time boundaries

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

setup_karafka

class Consumer < Karafka::BaseConsumer
  def tick
    @ticks ||= 0
    @ticks += 1

    sleep(5) if @ticks == 1

    DT[0] << true if @ticks == 10
  end
end

listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: '127.0.0.1',
  port: 9006,
  consuming_ttl: 1_000
)

Karafka.monitor.subscribe(listener)

raw_flows = +''

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)

    req = Net::HTTP::Get.new('/')
    client = Net::HTTP.new('127.0.0.1', 9006)
    client.set_debug_output(raw_flows)
    response = client.request(req)

    DT[:probing] << response.code
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic interval: 100
  end
end

start_karafka_and_wait_until do
  DT.key?(0)
end

assert DT[:probing].include?('204')
# 500 should happen as we tuned it aggressively and it should react to "hanging" tick
assert DT[:probing].include?('500')
