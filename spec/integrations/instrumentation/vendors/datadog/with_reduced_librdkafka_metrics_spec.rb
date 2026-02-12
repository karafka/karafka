# frozen_string_literal: true

# This test illustrates the cost reduction strategy from the wiki:
# By customizing rd_kafka_metrics to only include essential consumer lag metrics,
# we skip high-cardinality network latency and connection metrics that would otherwise
# increase DataDog costs without providing proportional observability value.

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

# Custom listener that only reports essential consumer lag metrics
# This demonstrates the cost-reduction approach from the wiki
class MinimalCostDatadogListener < Karafka::Instrumentation::Vendors::Datadog::MetricsListener
end

statsd_dummy = Vendors::Datadog::StatsdDummyClient.new

listener = MinimalCostDatadogListener.new do |config|
  config.client = statsd_dummy
  config.default_tags = ["host:#{Socket.gethostname}"]

  ref = MinimalCostDatadogListener

  # Only report essential metrics: messages consumed and consumer lag
  # Skip expensive high-cardinality metrics: network latency and connection metrics
  # This significantly reduces DataDog costs while maintaining visibility into what matters
  config.rd_kafka_metrics = [
    # Keep basic consumption metrics (relatively low cost)
    ref::RdKafkaMetric.new(:count, :root, "messages.consumed", "rxmsgs_d"),
    ref::RdKafkaMetric.new(:count, :root, "messages.consumed.bytes", "rxmsg_bytes"),
    # Keep essential lag metrics (what we care about)
    ref::RdKafkaMetric.new(:gauge, :topics, "consumer.lags", "consumer_lag_stored"),
    ref::RdKafkaMetric.new(:gauge, :topics, "consumer.lags_delta", "consumer_lag_stored_d")
  ]
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && sleep(5)
end

# Standard application-level metrics and selected librdkafka metrics should be present
%w[
  karafka.messages.consumed
  karafka.messages.consumed.bytes
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

# Essential consumer lag metrics should be present (these are what we care about)
%w[
  karafka.consumer.lags
  karafka.consumer.lags_delta
].each do |gauge_key|
  assert_equal true, statsd_dummy.buffer[:gauge].key?(gauge_key), "#{gauge_key} missing"
end

# Expensive network latency metrics should NOT be present (cost reduction)
# These are high-cardinality per-broker metrics that significantly increase costs
%w[
  karafka.network.latency.avg
  karafka.network.latency.p95
  karafka.network.latency.p99
].each do |gauge_key|
  assert_equal false, statsd_dummy.buffer[:gauge].key?(gauge_key), "#{gauge_key} should be excluded"
end

# Connection metrics should NOT be present (cost reduction)
# These per-broker metrics add cost without proportional value
%w[
  karafka.connection.connects
  karafka.connection.disconnects
].each do |count_key|
  assert_equal false, statsd_dummy.buffer[:count].key?(count_key), "#{count_key} should be excluded"
end

# Other broker-level error metrics should NOT be present (not in our minimal config)
%w[
  karafka.consume.attempts
  karafka.consume.errors
  karafka.receive.errors
].each do |count_key|
  assert_equal false, statsd_dummy.buffer[:count].key?(count_key), "#{count_key} should be excluded"
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
