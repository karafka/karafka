# frozen_string_literal: true

# This test verifies that statistics.emitted events are properly propagated to custom listeners
# that inherit from the DataDog MetricsListener and override some (but not all) event handlers.
#
# This is a regression test for a user-reported issue where a custom listener that overrode
# methods like on_connection_listener_fetch_loop_received, on_consumer_revoked, etc. appeared
# to not receive statistics.emitted events.
#
# The test mimics the user's setup:
# - Custom listener inheriting from Karafka::Instrumentation::Vendors::Datadog::MetricsListener
# - Overrides several methods with no-op implementations to suppress unwanted metrics
# - Does NOT override on_statistics_emitted, relying on parent implementation

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
# Overrides several methods to suppress metrics we don't care about
# but does NOT override on_statistics_emitted
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
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleep makes karafka run a bit longer for more metrics to kick in
  # Same pattern as metrics_flow_spec.rb
  DT[0].size >= 100 && sleep(5)
end

# Verify on_statistics_emitted was actually called
assert DT[:statistics_emitted_called].size >= 3,
  "Expected on_statistics_emitted to be called at least 3 times, " \
  "but was called #{DT[:statistics_emitted_called].size} times"

# Verify all calls were for the correct consumer group
DT[:statistics_emitted_called].each do |cg_id|
  assert_equal DT.consumer_group.to_s, cg_id,
    "Expected consumer_group_id to be #{DT.consumer_group}, got #{cg_id}"
end

# Verify statistics-derived metrics were published (from on_statistics_emitted)
# These are the metrics that come from the rd_kafka_metrics configuration
%w[
  karafka.messages.consumed
  karafka.messages.consumed.bytes
].each do |count_key|
  assert_equal true, statsd_dummy.buffer[:count].key?(count_key),
    "#{count_key} missing - on_statistics_emitted metrics not being published"
end

# Verify consumer lag metrics from statistics (these come from on_statistics_emitted)
%w[
  karafka.consumer.lags
  karafka.consumer.lags_delta
].each do |gauge_key|
  assert_equal true, statsd_dummy.buffer[:gauge].key?(gauge_key),
    "#{gauge_key} missing - on_statistics_emitted metrics not being published"
end

# Verify broker-level metrics from statistics (these come from on_statistics_emitted)
%w[
  karafka.network.latency.avg
  karafka.network.latency.p95
  karafka.network.latency.p99
].each do |gauge_key|
  assert_equal true, statsd_dummy.buffer[:gauge].key?(gauge_key),
    "#{gauge_key} missing - broker-level statistics metrics not being published"
end

# Verify that the overridden methods effectively suppressed their metrics
# These metrics should NOT be present because we overrode the handlers with no-ops

# on_worker_process publishes worker.total_threads, worker.processing, worker.enqueued_jobs
# Since we overrode it with no-op, these should not be present
%w[
  karafka.worker.total_threads
].each do |gauge_key|
  assert_equal false, statsd_dummy.buffer[:gauge].key?(gauge_key),
    "#{gauge_key} should NOT be present since on_worker_process was overridden"
end

%w[
  karafka.worker.processing
  karafka.worker.enqueued_jobs
].each do |hist_key|
  assert_equal false, statsd_dummy.buffer[:histogram].key?(hist_key),
    "#{hist_key} should NOT be present since on_worker_process was overridden"
end

# on_connection_listener_fetch_loop_received publishes listener.polling.time_taken, listener.polling.messages
# Since we overrode it with no-op, these should not be present
%w[
  karafka.listener.polling.time_taken
  karafka.listener.polling.messages
].each do |hist_key|
  assert_equal false, statsd_dummy.buffer[:histogram].key?(hist_key),
    "#{hist_key} should NOT be present since on_connection_listener_fetch_loop_received was overridden"
end

# BUT metrics from on_consumer_consumed should still be present (we didn't override that)
%w[
  karafka.consumer.messages
  karafka.consumer.batches
].each do |count_key|
  assert_equal true, statsd_dummy.buffer[:count].key?(count_key),
    "#{count_key} missing - on_consumer_consumed was not overridden so should be present"
end

%w[
  karafka.consumer.consumed.time_taken
  karafka.consumer.batch_size
  karafka.consumer.processing_lag
  karafka.consumer.consumption_lag
].each do |hist_key|
  assert_equal true, statsd_dummy.buffer[:histogram].key?(hist_key),
    "#{hist_key} missing - on_consumer_consumed was not overridden so should be present"
end
