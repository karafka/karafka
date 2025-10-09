# frozen_string_literal: true

# We should be able to sub-class and limit the operational cost of DD listener if needed

require 'karafka/instrumentation/vendors/datadog/metrics_listener'
require Karafka.gem_root.join('spec/support/vendors/datadog/statsd_dummy_client')

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

class OptimizedDatadogListener < Karafka::Instrumentation::Vendors::Datadog::MetricsListener
  def initialize(*args)
    @statistics_counter = 0
    # Report 3 times less than statistics interval
    @report_every_n_stats = 3
    super
  end

  def on_statistics_emitted(event)
    @statistics_counter += 1
    return unless (@statistics_counter % @report_every_n_stats).zero?

    super
  end
end

statsd_dummy = Vendors::Datadog::StatsdDummyClient.new

listener = OptimizedDatadogListener.new do |config|
  config.client = statsd_dummy
  # Publish host as a tag alongside the rest of tags
  config.default_tags = ["host:#{Socket.gethostname}"]

  ref = OptimizedDatadogListener

  config.rd_kafka_metrics = [
    ref::RdKafkaMetric.new(:count, :root, 'messages.consumed', 'rxmsgs_d'),
    ref::RdKafkaMetric.new(:count, :root, 'messages.consumed.bytes', 'rxmsg_bytes'),
    ref::RdKafkaMetric.new(:gauge, :topics, 'consumer.lags', 'consumer_lag_stored'),
    ref::RdKafkaMetric.new(:gauge, :topics, 'consumer.lags_delta', 'consumer_lag_stored_d')
  ]
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && sleep(5)
end

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

error_tracks = statsd_dummy.buffer[:count]['karafka.error_occurred']

# Expect to have one error report from te consumption
assert_equal 1, error_tracks.size
assert_equal 1, error_tracks[0][0]
assert_equal true, error_tracks[0][1][:tags].include?('type:consumer.consume.error')

%w[
  karafka.consumer.lags
  karafka.consumer.lags_delta
].each do |gauge_key|
  assert_equal true, statsd_dummy.buffer[:gauge].key?(gauge_key), "#{gauge_key} missing"
end

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
