# frozen_string_literal: true

# An idle connection to the swarm liveness probe server (connects, sends nothing) must not block
# the probes that come after it for longer than the configured client read timeout

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/swarm_liveness_listener"

setup_karafka

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts("1")
    WRITER.flush
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::SwarmLivenessListener.new(
  hostname: "127.0.0.1",
  port: 9027,
  client_read_timeout: 1_000
)

Karafka.monitor.subscribe(listener)

Thread.new do
  sleep(0.1) until Karafka::App.supervising?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  idle = TCPSocket.new("127.0.0.1", 9027)

  client = Net::HTTP.new("127.0.0.1", 9027)
  client.read_timeout = 3

  code =
    begin
      client.request(Net::HTTP::Get.new("/")).code
    rescue Net::ReadTimeout
      "timeout"
    end

  DT[:probing] << code

  idle.close
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

consumed = false

start_karafka_and_wait_until(mode: :swarm) do
  consumed ||= !READER.gets.nil?
  consumed && DT.key?(:probing)
end

assert_equal %w[200], DT[:probing]
