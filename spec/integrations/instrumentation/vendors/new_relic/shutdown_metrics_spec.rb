# frozen_string_literal: true

# Shutdown publishes a consumer.shutdown metric whose name carries the consumer group, topic and
# partition, built through the same helper as the consume and revocation paths. New Relic custom
# metrics cannot take tags, so that suffix is the only thing keeping shutdowns of different
# groups, topics and partitions apart.
require "karafka/instrumentation/vendors/new_relic/metrics_listener"
require Karafka.gem_root.join("spec/support/vendors/new_relic/dummy_client")

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:partition] = messages.metadata.partition
    DT[:consumed] = true
  end

  def shutdown
    DT[:shutdown] = true
  end
end

dummy_client = Vendors::NewRelic::DummyClient.new

listener = Karafka::Instrumentation::Vendors::NewRelic::MetricsListener.new do |config|
  config.client = dummy_client
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce(DT.topic, "shut-me-down", partition: 0)

start_karafka_and_wait_until do
  DT.key?(:consumed)
end

assert DT.key?(:shutdown), "Shutdown never ran, cannot assert its metric"

shutdown_keys = dummy_client.buffer.keys.select { |key| key.include?("consumer.shutdown") }

assert shutdown_keys.any?, "No consumer.shutdown metric recorded"

# Custom/{namespace}/consumer.shutdown.{group}.{topic}.{partition}
expected = "Custom/karafka/consumer.shutdown.#{DT.group}.#{DT.topic}.#{DT[:partition]}"

assert_equal(
  [expected],
  shutdown_keys,
  "consumer.shutdown metric name must carry group, topic and partition"
)

dummy_client.buffer[expected].each do |value|
  assert_equal 1, value, "Each shutdown should record a count of 1, got #{value}"
end
