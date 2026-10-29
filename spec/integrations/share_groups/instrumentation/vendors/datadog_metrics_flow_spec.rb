# frozen_string_literal: true

# The Datadog metrics listener should work with share groups (KIP-932) without breaking any
# notifications: consumption, errors, workers and librdkafka statistics based metrics should be
# published for share consumers as well. Consumer-group partition offsets and lags do not apply.

require "karafka/instrumentation/vendors/datadog/metrics_listener"
require Karafka.gem_root.join("spec/support/vendors/datadog/statsd_dummy_client")

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    unless @raised
      @raised = true
      raise StandardError
    end

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

statsd_dummy = Vendors::Datadog::StatsdDummyClient.new

listener = Karafka::Instrumentation::Vendors::Datadog::MetricsListener.new do |config|
  config.client = statsd_dummy
  config.default_tags = ["host:#{Socket.gethostname}"]
end

Karafka.monitor.subscribe(listener)

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # Let it run a bit longer for more metrics to kick in
  DT[:accepted].uniq.size >= 100 && sleep(3)
end

%w[
  karafka.messages.consumed
  karafka.messages.consumed.bytes
  karafka.connection.connects
  karafka.error_occurred
  karafka.consumer.messages
  karafka.consumer.batches
  karafka.consumer.shutdown
].each do |count_key|
  assert statsd_dummy.buffer[:count].key?(count_key), "#{count_key} missing"
end

error_tracks = statsd_dummy.buffer[:count]["karafka.error_occurred"]

assert_equal 1, error_tracks.size
assert error_tracks[0][1][:tags].include?("type:consumer.consume.error")

%w[
  karafka.network.latency.avg
  karafka.worker.total_threads
].each do |gauge_key|
  assert statsd_dummy.buffer[:gauge].key?(gauge_key), "#{gauge_key} missing"
end

%w[
  karafka.worker.processing
  karafka.worker.enqueued_jobs
  karafka.consumer.consumed.time_taken
  karafka.consumer.batch_size
  karafka.consumer.processing_lag
  karafka.consumer.consumption_lag
].each do |hist_key|
  assert statsd_dummy.buffer[:histogram].key?(hist_key), "#{hist_key} missing"
end

batch_tags = statsd_dummy.buffer[:count]["karafka.consumer.batches"].map { |_, opts| opts[:tags] }

assert batch_tags.flatten.include?("consumer_group:#{DT.group}"), batch_tags.first
assert batch_tags.flatten.include?("topic:#{DT.topic}"), batch_tags.first
