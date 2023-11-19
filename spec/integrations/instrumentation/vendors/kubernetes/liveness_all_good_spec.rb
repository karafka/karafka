# frozen_string_literal: true

# When all good, all should be ok

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

# Raise consumer error, just to make sure this does not impact liveness
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

begin
  port = rand(3000..5000)
  listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
    hostname: '127.0.0.1',
    port: port
  )
rescue Errno::EADDRINUSE
  retry
end

Karafka.monitor.subscribe(listener)

raw_flows = +''

Thread.new do
  until Karafka::App.stopping?
    sleep(0.1)

    req = Net::HTTP::Get.new('/')
    client = Net::HTTP.new('127.0.0.1', port)
    client.set_debug_output(raw_flows)
    response = client.request(req)

    DT[:probing] << response.code
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(0)
end

assert DT[:probing].include?('204')
assert !DT[:probing].include?('500')

responses = raw_flows.split("\n").select { |line| line.start_with?('->') }

assert_equal responses[0], '-> "HTTP/1.1 204 No Content\r\n"', responses[0]
assert_equal responses[1], '-> "Content-Type: text/plain\r\n"', responses[1]
assert_equal responses[2], '-> "\r\n"', responses[2]
