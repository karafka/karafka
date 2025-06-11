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

listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: '127.0.0.1',
  port: 9003
)

Karafka.monitor.subscribe(listener)

raw_flows = +''

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)

    req = Net::HTTP::Get.new('/')
    client = Net::HTTP.new('127.0.0.1', 9003)
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

assert DT[:probing].include?('200')
assert !DT[:probing].include?('500')

responses = raw_flows.split("\n").select { |line| line.start_with?('->') }

assert_equal responses[0], '-> "HTTP/1.1 200 OK\r\n"', responses[0]
assert_equal responses[1], '-> "Content-Type: application/json\r\n"', responses[1]

last = JSON.parse(DT[:bodies].last)

assert_equal 'healthy', last['status']
assert last.key?('timestamp')
assert_equal 9003, last['port']
assert_equal Process.pid, last['process_id']
assert_equal false, last['errors']['polling_ttl_exceeded']
assert_equal false, last['errors']['consumption_ttl_exceeded']
assert_equal false, last['errors']['unrecoverable']
