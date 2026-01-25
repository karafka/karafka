# frozen_string_literal: true

# Here we subscribe to our listener and make sure nothing breaks during the notifications
# We use a dummy client that will intercept calls that should go to Appsignal and check basic
# metrics presence
require "karafka/instrumentation/vendors/appsignal/metrics_listener"
require Karafka.gem_root.join("spec/support/vendors/appsignal/dummy_client")

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

appsignal_dummy = Vendors::Appsignal::DummyClient.new

listener = Karafka::Instrumentation::Vendors::Appsignal::MetricsListener.new do |config|
  config.client = appsignal_dummy
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && sleep(5)
end

%w[
  karafka_requests_retries
  karafka_transmission_errors
  karafka_receive_errors
  karafka_connection_connects
  karafka_connection_disconnects
  karafka_consumer_errors
  karafka_consumer_messages
  karafka_consumer_batches
  karafka_processes_count
  karafka_threads_count
].each do |count_key|
  assert_equal true, appsignal_dummy.buffer[:count].key?(count_key), "#{count_key} missing"
end

transactions_started = appsignal_dummy.buffer[:start_transaction].values.flatten
transactions_ended = appsignal_dummy.buffer[:stop_transaction].values.flatten

assert !transactions_started.empty?
assert !transactions_ended.empty?
assert_equal transactions_started.size, transactions_ended.size

# We should not report errors from metrics listener
error_tracks = appsignal_dummy.buffer[:errors][0]
assert_equal [], error_tracks

%w[
  karafka_network_latency_avg
  karafka_network_latency_p95
  karafka_network_latency_p99
  karafka_consumer_offsets
  karafka_consumer_lag
  karafka_consumer_lag_delta
  karafka_consumer_aggregated_lag
].each do |gauge_key|
  assert_equal true, appsignal_dummy.buffer[:gauge].key?(gauge_key), "#{gauge_key} missing"
end

assert appsignal_dummy.buffer[:probes].key?(:karafka)
