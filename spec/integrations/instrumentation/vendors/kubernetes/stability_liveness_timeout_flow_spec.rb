# frozen_string_literal: true

# When a subscription group's consumer group join_state stays non-steady longer than the
# stability TTL, the liveness probe should return 500 with stability_ttl_exceeded true.
# When join_state recovers to steady, the probe should return 200 again.

require "net/http"
require "karafka/instrumentation/vendors/kubernetes/liveness_listener"

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(Consumer)

listener = Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: "127.0.0.1",
  port: 9014,
  stability_ttl: 300
)

def stats_event(join_state:)
  { subscription_group_id: "sg1", statistics: { "cgrp" => { "join_state" => join_state } } }
end

# Start the TCP server directly (bypasses the on_app_running lifecycle)
listener.send(:start)
sleep(0.1)

def probe(port)
  uri = URI.parse("http://127.0.0.1:#{port}/")
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body)
end

# Initially healthy with no statistics received
initial = probe(9014)
assert_equal "healthy", initial["status"]
assert_equal false, initial["errors"]["stability_ttl_exceeded"]

# Simulate consumer stuck in non-steady join state
listener.on_statistics_emitted(stats_event(join_state: "wait-assn"))

# Wait for the stability TTL (300ms) to expire
sleep(0.5)

unhealthy = probe(9014)
assert_equal "unhealthy", unhealthy["status"]
assert_equal true, unhealthy["errors"]["stability_ttl_exceeded"]
assert_equal false, unhealthy["errors"]["polling_ttl_exceeded"]
assert_equal false, unhealthy["errors"]["consumption_ttl_exceeded"]
assert_equal false, unhealthy["errors"]["unrecoverable"]

# Simulate recovery: join_state returns to steady
listener.on_statistics_emitted(stats_event(join_state: "steady"))

recovered = probe(9014)
assert_equal "healthy", recovered["status"]
assert_equal false, recovered["errors"]["stability_ttl_exceeded"]
