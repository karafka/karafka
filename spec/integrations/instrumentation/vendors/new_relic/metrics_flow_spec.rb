# frozen_string_literal: true

# Subscribes the New Relic metrics listener and verifies that the expected metrics
# are recorded after consumption. Uses a dummy client to avoid a real NR agent.
require "karafka/instrumentation/vendors/new_relic/metrics_listener"
require Karafka.gem_root.join("spec/support/vendors/new_relic/dummy_client")

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    unless @raised
      @raised = true
      raise StandardError
    end

    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

dummy_client = Vendors::NewRelic::DummyClient.new

listener = Karafka::Instrumentation::Vendors::NewRelic::MetricsListener.new do |config|
  config.client = dummy_client
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[0].size >= 100 && sleep(5)
end

# Consumer lag metrics (published from statistics.emitted)
lag_metrics = dummy_client.buffer.keys.select { |k| k.include?("consumer.lags") }
assert_equal true, lag_metrics.any?, "No consumer.lags metrics recorded"

lag_metrics.each do |key|
  dummy_client.buffer[key].each do |value|
    assert_equal true, value >= 0, "Unexpected negative lag for #{key}: #{value}"
  end
end

# Consumer batch metrics (published from consumer.consumed)
batch_metrics = dummy_client.buffer.keys.select { |k| k.include?("consumer.messages") }
assert_equal true, batch_metrics.any?, "No consumer.messages metrics recorded"

# Worker metrics (published from worker.process)
assert_equal(
  true,
  dummy_client.buffer.keys.any? { |k| k.include?("worker.total_threads") },
  "No worker.total_threads metric recorded"
)

# Error metric (published from error.occurred — one error is raised during consumption)
error_metrics = dummy_client.buffer.keys.select { |k| k.include?("error_occurred") }
assert_equal true, error_metrics.any?, "No error_occurred metric recorded"
