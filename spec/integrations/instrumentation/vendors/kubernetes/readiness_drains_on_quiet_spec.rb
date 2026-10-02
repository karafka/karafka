# frozen_string_literal: true

# The readiness probe reports ready while the process is actively polling, and reports not-ready as
# soon as the process starts draining (moves to quiet), so Kubernetes can pull the pod out of the
# Service endpoints before it exits. This draining behaviour is readiness-specific - a liveness
# probe would still report healthy here.
#
# The http server itself only stops on `app.stopped`, so while quiet the endpoint is still reachable
# and answers 500 (not-ready) rather than refusing the connection.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/readiness_listener"

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << true
  end
end

listener = Karafka::Instrumentation::Vendors::Kubernetes::ReadinessListener.new(
  hostname: "127.0.0.1",
  port: 9023
)

Karafka.monitor.subscribe(listener)

probe = lambda do
  uri = URI.parse("http://127.0.0.1:9023/")
  response = Net::HTTP.get_response(uri)
  [response.code, response.body]
end

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(0.5) # Give a bit of time for the tcp server to start after the app starts running

  # Probe until we observe ready (200): the process has started polling.
  loop do
    code, body = probe.call
    DT[:while_running] << code
    DT[:ready_body] = body if code == "200"
    break if code == "200"
    sleep(0.1)
  end

  # Start draining. A liveness probe would stay healthy; readiness must flip to not-ready.
  Karafka::Server.quiet

  # While quiet the server is still up, but readiness must now report not-ready (500).
  loop do
    code, body = probe.call
    DT[:while_draining] << code

    if code == "500"
      DT[:drained_body] = body
      break
    end

    sleep(0.1)
  end

  Karafka::Server.stop
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

# The probing thread drives the shutdown (quiet then stop) itself, so we just keep the server up.
start_karafka_and_wait_until do
  DT.key?(:drained_body)
end

# It was ready while running...
assert DT[:while_running].include?("200")
assert DT.key?(:ready_body)

ready = JSON.parse(DT[:ready_body])
assert_equal "healthy", ready["status"]
assert_equal true, ready["ready"]

# ...and reported not-ready once draining started.
assert DT[:while_draining].include?("500")
assert DT.key?(:drained_body)

drained = JSON.parse(DT[:drained_body])
assert_equal "unhealthy", drained["status"]
assert_equal false, drained["ready"]
assert_equal 9023, drained["port"]
assert_equal Process.pid, drained["process_id"]
