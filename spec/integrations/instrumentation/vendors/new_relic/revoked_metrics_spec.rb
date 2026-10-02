# frozen_string_literal: true

# Revocation publishes a consumer.revoked metric whose name carries the consumer group, topic and
# partition. New Relic custom metrics cannot take tags, so that context only exists in the metric
# name - if the suffix were dropped or mis-built, revocations from different groups, topics or
# partitions would silently collide into one metric.
#
# Revocation is triggered by exceeding max.poll.interval.ms, the same way the KIP-848 revocation
# specs do it.
require "karafka/instrumentation/vendors/new_relic/metrics_listener"
require Karafka.gem_root.join("spec/support/vendors/new_relic/dummy_client")

setup_karafka(allow_errors: true, consumer_group_protocol: true) do |config|
  config.kafka.delete(:"session.timeout.ms")
  config.kafka[:"max.poll.interval.ms"] = 5_000
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:partition] = messages.metadata.partition

    # Exceed max.poll.interval.ms so the broker kicks us out and revocation runs
    sleep(10)
  end

  def revoked
    DT[:revoked] = true
  end
end

dummy_client = Vendors::NewRelic::DummyClient.new

listener = Karafka::Instrumentation::Vendors::NewRelic::MetricsListener.new do |config|
  config.client = dummy_client
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce(DT.topic, "revoke-me", partition: 0)

# Wait on the metric itself: once revocation has been published there is nothing left to wait for
start_karafka_and_wait_until do
  dummy_client.buffer.keys.any? { |key| key.include?("consumer.revoked") }
end

assert DT.key?(:revoked), "Revocation never happened, cannot assert its metric"

revoked_keys = dummy_client.buffer.keys.select { |key| key.include?("consumer.revoked") }

assert revoked_keys.any?, "No consumer.revoked metric recorded, got #{dummy_client.buffer.keys}"

# The name must be fully scoped: Custom/{namespace}/consumer.revoked.{group}.{topic}.{partition}
expected = "Custom/karafka/consumer.revoked.#{DT.group}.#{DT.topic}.#{DT[:partition]}"

assert_equal(
  [expected],
  revoked_keys,
  "consumer.revoked metric name must carry group, topic and partition"
)

dummy_client.buffer[expected].each do |value|
  assert_equal 1, value, "Each revocation should record a count of 1, got #{value}"
end
