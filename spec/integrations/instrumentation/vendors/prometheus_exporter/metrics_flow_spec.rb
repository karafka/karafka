# frozen_string_literal: true

# Here we subscribe to our listener and make sure nothing breaks during the notifications
# We use a dummy client that will intercept calls that should go to DataDog and check basic
# metrics presence

require 'prometheus_exporter'
require 'prometheus_exporter/client'
require 'prometheus_exporter/server'
require 'karafka/instrumentation/vendors/prometheus_exporter/metrics_listener/on_statistics_emitted'
require 'karafka/instrumentation/vendors/prometheus_exporter/metrics_collector'
require 'karafka/instrumentation/vendors/prometheus_exporter/metrics_listener'
require Karafka.gem_root.join('spec/support/vendors/prometheus_exporter/dummy_client')

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

prom_dummy = Vendors::PrometheusExporter::DummyClient.new

listener = ::Karafka::Instrumentation::Vendors::PrometheusExporter::MetricsListener.new do |config|
  config.client = prom_dummy
  # Publish host as a tag alongside the rest of tags
  config.default_labels = { host: Socket.gethostname }
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && sleep(5)
end

%w[
  karafka_messages_consumed_total
  karafka_messages_consumed_bytes_total
  karafka_consume_attempts_total
  karafka_consume_errors_total
  karafka_receive_errors_total
  karafka_connection_attempts_total
  karafka_connection_disconnects_total
  karafka_error_total
  karafka_consumer_messages_total
  karafka_consumer_batches_total
  karafka_consumer_shutdown_total
].each do |count_key|
  assert_equal true, prom_dummy.collector.registry.key?(count_key), "#{count_key} missing"
end

error_tracks = prom_dummy.collector.registry['karafka_error_total']

# Expect to have one error report from te consumption
assert_equal 1, error_tracks.data.size
assert_equal true, error_tracks.data.all? do |(label, _value)|
  %w[host type topic partition consumer_group].all? { |key| label.key?(key) }
end
assert_equal true, error_tracks.data.keys.any? { |labels| labels["type"] == "consumer.consume.error" }

%w[
  karafka_network_latency_avg_seconds
  karafka_network_latency_p95_seconds
  karafka_network_latency_p99_seconds
  karafka_worker_threads
  karafka_consumer_offset
  karafka_consumer_lags
  karafka_consumer_lags_delta
].each do |gauge_key|
  assert_equal true, prom_dummy.collector.registry.key?(gauge_key), "#{gauge_key} missing"
end

%w[
  karafka_worker_threads
  karafka_worker_enqueued_jobs
  karafka_consumer_consumed_time_taken_seconds
  karafka_consumer_batch_size
  karafka_consumer_processing_lag_seconds
  karafka_consumer_consumption_lag_seconds
].each do |hist_key|
  assert_equal true, prom_dummy.collector.registry.key?(hist_key), "#{hist_key} missing"
end
