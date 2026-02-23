# frozen_string_literal: true

# This test demonstrates that when rd_kafka_metrics is set to an empty array,
# no statistics-derived metrics will be published even though on_statistics_emitted
# is still being called.
#
# This test was created to help diagnose a user-reported issue where statistics
# metrics were not appearing in DataDog. The root cause was setting rd_kafka_metrics = []
# in the listener configuration.

require "karafka/instrumentation/vendors/datadog/metrics_listener"
require Karafka.gem_root.join("spec/support/vendors/datadog/statsd_dummy_client")

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

# Custom listener that mimics the user's MinimalDatadogListener pattern
# with rd_kafka_metrics set to empty array
class MinimalDatadogListener < Karafka::Instrumentation::Vendors::Datadog::MetricsListener
  # Track that on_statistics_emitted was actually called (for verification)
  def on_statistics_emitted(event)
    DT[:statistics_emitted_called] << event[:consumer_group_id]
    super
  end

  # Override existing listener methods so we don't emit metrics we don't care about
  def on_connection_listener_fetch_loop_received(_event)
  end

  def on_consumer_revoked(_event)
  end

  def on_consumer_shutdown(_event)
  end

  def on_consumer_ticked(_event)
  end

  def on_worker_process(_event)
  end

  def on_worker_processed(_event)
  end
end

statsd_dummy = Vendors::Datadog::StatsdDummyClient.new

listener = MinimalDatadogListener.new do |config|
  config.client = statsd_dummy
  config.default_tags = ["host:#{Socket.gethostname}"]
  # THIS IS THE KEY CONFIGURATION ISSUE:
  # Setting rd_kafka_metrics to empty array means on_statistics_emitted
  # will be called but won't publish any metrics
  config.rd_kafka_metrics = []
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleep makes karafka run a bit longer for more metrics to kick in
  # Same pattern as metrics_flow_spec.rb
  DT[0].size >= 100 && sleep(5)
end

# Verify on_statistics_emitted WAS actually called - the event IS propagated
assert DT[:statistics_emitted_called].size >= 3,
  "Expected on_statistics_emitted to be called at least 3 times, " \
  "but was called #{DT[:statistics_emitted_called].size} times"

# Verify all calls were for the correct consumer group
DT[:statistics_emitted_called].each do |cg_id|
  assert_equal DT.consumer_group.to_s, cg_id,
    "Expected consumer_group_id to be #{DT.consumer_group}, got #{cg_id}"
end

# NOW THE KEY ASSERTIONS:
# Because rd_kafka_metrics = [], NO statistics-derived metrics should be published
# even though on_statistics_emitted was called multiple times

# These metrics come from rd_kafka_metrics and should NOT be present
%w[
  karafka.messages.consumed
  karafka.messages.consumed.bytes
].each do |count_key|
  assert_equal false, statsd_dummy.buffer[:count].key?(count_key),
    "#{count_key} should NOT be present when rd_kafka_metrics is empty"
end

# Consumer lag metrics from statistics should NOT be present
%w[
  karafka.consumer.lags
  karafka.consumer.lags_delta
].each do |gauge_key|
  assert_equal false, statsd_dummy.buffer[:gauge].key?(gauge_key),
    "#{gauge_key} should NOT be present when rd_kafka_metrics is empty"
end

# Broker-level metrics from statistics should NOT be present
%w[
  karafka.network.latency.avg
  karafka.network.latency.p95
  karafka.network.latency.p99
].each do |gauge_key|
  assert_equal false, statsd_dummy.buffer[:gauge].key?(gauge_key),
    "#{gauge_key} should NOT be present when rd_kafka_metrics is empty"
end

# Connection metrics should NOT be present
%w[
  karafka.consume.attempts
  karafka.consume.errors
  karafka.receive.errors
  karafka.connection.connects
  karafka.connection.disconnects
].each do |count_key|
  assert_equal false, statsd_dummy.buffer[:count].key?(count_key),
    "#{count_key} should NOT be present when rd_kafka_metrics is empty"
end

# BUT metrics from on_consumer_consumed should still be present
# (we didn't override that method, and it doesn't depend on rd_kafka_metrics)
%w[
  karafka.consumer.messages
  karafka.consumer.batches
].each do |count_key|
  assert_equal true, statsd_dummy.buffer[:count].key?(count_key),
    "#{count_key} should be present - on_consumer_consumed doesn't depend on rd_kafka_metrics"
end

%w[
  karafka.consumer.consumed.time_taken
  karafka.consumer.batch_size
  karafka.consumer.processing_lag
  karafka.consumer.consumption_lag
].each do |hist_key|
  assert_equal true, statsd_dummy.buffer[:histogram].key?(hist_key),
    "#{hist_key} should be present - on_consumer_consumed doesn't depend on rd_kafka_metrics"
end
