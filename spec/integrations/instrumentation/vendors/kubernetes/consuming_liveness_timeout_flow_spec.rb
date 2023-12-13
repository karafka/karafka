# frozen_string_literal: true

# When consuming takes more time then expected, we should see that in the status

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
  port: 9002,
  consuming_ttl: 1_000
)

Karafka.monitor.subscribe(listener)

raw_flows = +''

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    req = Net::HTTP::Get.new('/')
    client = Net::HTTP.new('127.0.0.1', 9002)
    client.set_debug_output(raw_flows)
    response = client.request(req)

    DT[:probing] << response.code

    sleep(0.1)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(0)
end

assert DT[:probing].include?('204')
assert DT[:probing].include?('500')

responses = raw_flows.split("\n").select { |line| line.start_with?('->') }

assert_equal responses[0], '-> "HTTP/1.1 204 No Content\r\n"', responses[0]
assert_equal responses[1], '-> "Content-Type: text/plain\r\n"', responses[1]
assert_equal responses[2], '-> "\r\n"', responses[2]

position = responses.index { |line| line.include?(' 500 ') }

resp500 = responses[position..]

assert_equal resp500[0], '-> "HTTP/1.1 500 Internal Server Error\r\n"', resp500[0]
assert_equal resp500[1], '-> "Content-Type: text/plain\r\n"', resp500[1]
assert_equal resp500[2], '-> "\r\n"', resp500[2]
