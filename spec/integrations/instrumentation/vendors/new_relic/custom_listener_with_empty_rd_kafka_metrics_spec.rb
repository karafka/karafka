# frozen_string_literal: true

# When rd_kafka_metrics is set to an empty array, no statistics-derived metrics are published
# even though on_statistics_emitted still runs. Everything that does not read rd_kafka_metrics
# (here: the consumer.consumed metrics) must keep being published.
#
# This mirrors the equivalent Datadog spec: an empty list is a configuration users reach for when
# they want to suppress librdkafka metrics, and it must degrade quietly rather than break the
# listener.
require "karafka/instrumentation/vendors/new_relic/metrics_listener"
require Karafka.gem_root.join("spec/support/vendors/new_relic/dummy_client")

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

# Tracks that the event still reaches the listener, while delegating to the parent implementation
class TrackingListener < Karafka::Instrumentation::Vendors::NewRelic::MetricsListener
  def on_statistics_emitted(event)
    DT[:statistics_emitted_called] << event[:group_id]
    super
  end
end

dummy_client = Vendors::NewRelic::DummyClient.new

listener = TrackingListener.new do |config|
  config.client = dummy_client
  config.rd_kafka_metrics = []
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[0].size >= 100 && sleep(5)
end

# The event is still propagated - the empty list suppresses publication, not the callback
assert(
  DT[:statistics_emitted_called].size >= 3,
  "Expected on_statistics_emitted to run at least 3 times, " \
  "got #{DT[:statistics_emitted_called].size}"
)

DT[:statistics_emitted_called].each do |group_id|
  assert_equal DT.group.to_s, group_id, "Unexpected group id: #{group_id}"
end

# Nothing derived from rd_kafka_metrics may be published
%w[
  messages.consumed
  consumer.lags
  consumer.lags_delta
  consume.attempts
  consume.errors
  receive.errors
  connection.connects
  connection.disconnects
  network.latency
].each do |fragment|
  offenders = dummy_client.buffer.keys.select { |key| key.include?(fragment) }

  assert_equal(
    [],
    offenders,
    "#{fragment} must not be published when rd_kafka_metrics is empty, got #{offenders}"
  )
end

# Metrics that do not read rd_kafka_metrics must still be published
%w[
  consumer.messages
  consumer.batches
  consumer.offset
  consumer.batch_size
].each do |fragment|
  assert(
    dummy_client.buffer.keys.any? { |key| key.include?(fragment) },
    "#{fragment} should still be published - it does not depend on rd_kafka_metrics"
  )
end
