# frozen_string_literal: true

# An idle connection to the readiness probe server (connects, sends nothing) must not block the
# probes that come after it for longer than the configured client read timeout

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/readiness_listener"

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::ReadinessListener.new(
  hostname: "127.0.0.1",
  port: 9026,
  client_read_timeout: 1_000
)

Karafka.monitor.subscribe(listener)

Thread.new do
  # Probe once consuming, so the probe status is healthy
  sleep(0.1) until DT.key?(0)

  idle = TCPSocket.new("127.0.0.1", 9026)

  client = Net::HTTP.new("127.0.0.1", 9026)
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

start_karafka_and_wait_until do
  DT.key?(:probing)
end

assert_equal %w[200], DT[:probing]
