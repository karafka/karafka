# frozen_string_literal: true

# When we expect to control nodes more often that it happens, it should be reflected

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/swarm_liveness_listener'

setup_karafka

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts('1')
    WRITER.flush
  end
end

listener = ::Karafka::Instrumentation::Vendors::Kubernetes::SwarmLivenessListener.new(
  hostname: '127.0.0.1',
  port: 9010,
  controlling_ttl: 100
)

Karafka.monitor.subscribe(listener)

raw_flows = +''

Thread.new do
  sleep(0.1) until Karafka::App.supervising?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  until Karafka::App.stopping?
    sleep(0.1)

    req = Net::HTTP::Get.new('/')
    client = Net::HTTP.new('127.0.0.1', 9010)
    client.set_debug_output(raw_flows)
    response = client.request(req)

    DT[:probing] << response.code
    DT[:bodies] << response.body
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until(mode: :swarm) do
  READER.gets
end

assert DT[:probing].include?('500')

responses = raw_flows.split("\n").select { |line| line.start_with?('->') }

assert_equal responses[0], '-> "HTTP/1.1 500 Internal Server Error\r\n"', responses[0]
assert_equal responses[1], '-> "Content-Type: application/json\r\n"', responses[1]
assert responses[2].include?('Content-Length: '), responses[2]
assert_equal responses[3], '-> "\r\n"', responses[3]

last = JSON.parse(DT[:bodies].last)

assert_equal 'unhealthy', last['status']
assert last.key?('timestamp')
assert_equal 9010, last['port']
assert_equal Process.pid, last['process_id']
assert_equal true, last['errors']['controlling_ttl_exceeded']
