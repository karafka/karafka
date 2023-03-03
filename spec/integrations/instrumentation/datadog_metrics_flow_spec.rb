# frozen_string_literal: true

# Here we subscribe to our listener and make sure nothing breaks during the notifications
# We use a dummy client that will intercept calls that should go to DataDog and check basic
# metrics presence
require 'karafka/instrumentation/vendors/datadog/listener' # backwards compatible listener
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

statsd_dummy = Vendors::Datadog::StatsdDummyClient.new

listener = ::Karafka::Instrumentation::Vendors::Datadog::MetricsListener.new do |config|
  config.client = statsd_dummy
  # Publish host as a tag alongside the rest of tags
  config.default_tags = ["host:#{Socket.gethostname}"]
end

Karafka.monitor.subscribe(listener)

# @note this sets up the old Listener class to make sure we keep backwards compatibility
statsd_dummy_for_backwards_compatibility = Vendors::Datadog::StatsdDummyClient.new
deprecated_listener = ::Karafka::Instrumentation::Vendors::Datadog::Listener.new do |config|
  config.client = statsd_dummy_for_backwards_compatibility
  # Publish host as a tag alongside the rest of tags
  config.default_tags = ["host:#{Socket.gethostname}"]
end
Karafka.monitor.subscribe(deprecated_listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && sleep(5)
end

# TODO: remove this loop when Listener is finally deprecated
[statsd_dummy, statsd_dummy_for_backwards_compatibility].each do |statsd_client|
  %w[
    karafka.messages.consumed
    karafka.messages.consumed.bytes
    karafka.consume.attempts
    karafka.consume.errors
    karafka.receive.errors
    karafka.connection.connects
    karafka.connection.disconnects
    karafka.error_occurred
    karafka.consumer.messages
    karafka.consumer.batches
    karafka.consumer.shutdown
  ].each do |count_key|
    assert_equal true, statsd_client.buffer[:count].key?(count_key), "#{count_key} missing"
  end

  error_tracks = statsd_client.buffer[:count]['karafka.error_occurred']

  # Expect to have one error report from te consumption
  assert_equal 1, error_tracks.size
  assert_equal 1, error_tracks[0][0]
  assert_equal true, error_tracks[0][1][:tags].include?('type:consumer.consume.error')

  %w[
    karafka.network.latency.avg
    karafka.network.latency.p95
    karafka.network.latency.p99
    karafka.worker.total_threads
    karafka.consumer.offset
    karafka.consumer.lags
    karafka.consumer.lags_delta
  ].each do |gauge_key|
    assert_equal true, statsd_client.buffer[:gauge].key?(gauge_key), "#{gauge_key} missing"
  end

  %w[
    karafka.worker.processing
    karafka.worker.enqueued_jobs
    karafka.consumer.consumed.time_taken
    karafka.consumer.batch_size
    karafka.consumer.processing_lag
    karafka.consumer.consumption_lag
  ].each do |hist_key|
    assert_equal true, statsd_client.buffer[:histogram].key?(hist_key), "#{hist_key} missing"
  end
end
