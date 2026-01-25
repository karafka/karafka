# frozen_string_literal: true

# Karafka should publish async errors from all the clients via a dedicated instrumentation hooks
# and they should not collide with each other.
# If they would, events would be published twice.

setup_karafka(allow_errors: true) do |config|
  # Bad port on purpose to trigger the error
  config.kafka = { "bootstrap.servers": "127.0.0.1:9090" }
end

draw_routes(nil, create_topics: false) do
  consumer_group DT.consumer_groups.first do
    topic DT.topic do
      consumer Class.new
    end
  end

  consumer_group DT.consumer_groups.last do
    topic DT.topic do
      consumer Class.new
    end
  end
end

error_events = {}

Karafka::App.monitor.subscribe("error.occurred") do |event|
  error_events[event[:subscription_group_id]] ||= []
  error_events[event[:subscription_group_id]] << event
end

# Make sure that we have enough events from all the subscription groups
start_karafka_and_wait_until do
  error_events.size >= 2 &&
    error_events.values.all? { |errors| errors.size >= 2 }
end

assert_equal 2, error_events.keys.size

g1 = error_events.values.first.map { |event| event.payload[:error] }
g2 = error_events.values.last.map { |event| event.payload[:error] }

# Each error published, should be published only once
# If this would not be true, all would go everywhere
assert !g1.intersect?(g2)

assert_equal "error.occurred", error_events.values.first.first.id
assert_equal "librdkafka.error", error_events.values.first.first[:type]
