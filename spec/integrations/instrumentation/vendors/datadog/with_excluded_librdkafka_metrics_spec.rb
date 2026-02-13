# frozen_string_literal: true

# This test illustrates the metric exclusion strategy from the wiki:
# By using exclude_rd_kafka_metrics, users can keep most default metrics while excluding
# specific high-cardinality ones (like certain network latency percentiles) without having
# to manually recreate the entire default metrics list. This reduces DataDog costs while
# maintaining most observability.

require "karafka/instrumentation/vendors/datadog/metrics_listener"
require Karafka.gem_root.join("spec/support/vendors/datadog/statsd_dummy_client")

# We allow errors to raise one to make sure things are published as expected
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

# Extended listener with metric exclusion support
# This demonstrates the exclusion approach from the wiki
class CustomDatadogListener < Karafka::Instrumentation::Vendors::Datadog::MetricsListener
  # Metric names to exclude from the default rdkafka metrics
  setting :exclude_rd_kafka_metrics, default: []

  # Override to apply exclusions dynamically
  def rd_kafka_metrics
    metrics = config.rd_kafka_metrics
    exclusions = config.exclude_rd_kafka_metrics

    return metrics if exclusions.empty?

    # Only apply exclusions when using the default metrics
    # If user provided custom metrics, we don't touch them
    if metrics == self.class.superclass.config.rd_kafka_metrics
      metrics.reject { |metric| exclusions.include?(metric.name) }
    else
      metrics
    end
  end
end

statsd_dummy = Vendors::Datadog::StatsdDummyClient.new

listener = CustomDatadogListener.new do |config|
  config.client = statsd_dummy
  config.default_tags = ["host:#{Socket.gethostname}"]

  # Exclude expensive network latency percentiles and connection metrics
  # while keeping p95, consumer lags, and other useful metrics
  config.exclude_rd_kafka_metrics = [
    "network.latency.avg",
    "network.latency.p99",
    "connection.connects",
    "connection.disconnects"
  ]
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && sleep(5)
end

# Standard application-level metrics should be present
%w[
  karafka.error_occurred
  karafka.consumer.messages
  karafka.consumer.batches
  karafka.consumer.shutdown
].each do |count_key|
  assert_equal true, statsd_dummy.buffer[:count].key?(count_key), "#{count_key} missing"
end

error_tracks = statsd_dummy.buffer[:count]["karafka.error_occurred"]

# Expect to have one error report from the consumption
assert_equal 1, error_tracks.size
assert_equal 1, error_tracks[0][0]
assert_equal true, error_tracks[0][1][:tags].include?("type:consumer.consume.error")

# Non-excluded librdkafka metrics should be present
%w[
  karafka.messages.consumed
  karafka.messages.consumed.bytes
].each do |count_key|
  assert_equal true, statsd_dummy.buffer[:count].key?(count_key), "#{count_key} missing"
end

# Consumer lag metrics should be present (not excluded)
%w[
  karafka.consumer.lags
  karafka.consumer.lags_delta
].each do |gauge_key|
  assert_equal true, statsd_dummy.buffer[:gauge].key?(gauge_key), "#{gauge_key} missing"
end

# Network latency p95 should be present (NOT excluded)
assert_equal true, statsd_dummy.buffer[:gauge].key?("karafka.network.latency.p95"),
  "network.latency.p95 should be present (not excluded)"

# Excluded network latency metrics should NOT be present
%w[
  karafka.network.latency.avg
  karafka.network.latency.p99
].each do |gauge_key|
  assert_equal false, statsd_dummy.buffer[:gauge].key?(gauge_key),
    "#{gauge_key} should be excluded"
end

# Excluded connection metrics should NOT be present
%w[
  karafka.connection.connects
  karafka.connection.disconnects
].each do |count_key|
  assert_equal false, statsd_dummy.buffer[:count].key?(count_key),
    "#{count_key} should be excluded"
end

# Non-excluded broker-level error metrics should still be present
%w[
  karafka.consume.attempts
  karafka.consume.errors
  karafka.receive.errors
].each do |count_key|
  assert_equal true, statsd_dummy.buffer[:count].key?(count_key), "#{count_key} missing"
end

# Standard histogram metrics should still be present
%w[
  karafka.worker.processing
  karafka.worker.enqueued_jobs
  karafka.consumer.consumed.time_taken
  karafka.consumer.batch_size
  karafka.consumer.processing_lag
  karafka.consumer.consumption_lag
].each do |hist_key|
  assert_equal true, statsd_dummy.buffer[:histogram].key?(hist_key), "#{hist_key} missing"
end
