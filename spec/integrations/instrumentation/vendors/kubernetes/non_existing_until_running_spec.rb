# frozen_string_literal: true

# If Karafka is configured but not started, the liveness probing should not work

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume; end
end

listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: '127.0.0.1',
  port: 9004
)

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

sleep(1)

not_available = false

begin
  req = Net::HTTP::Get.new('/')
  client = Net::HTTP.new('127.0.0.1', 9004)
  client.request(req)
rescue Errno::ECONNREFUSED
  not_available = true
end

assert not_available
