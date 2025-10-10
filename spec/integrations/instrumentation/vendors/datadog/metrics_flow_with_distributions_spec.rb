# frozen_string_literal: true

# Here we subscribe to our listener and make sure nothing breaks during the notifications
# We use a dummy client that will intercept calls that should go to DataDog and check basic
# metrics presence.
# Listener is instantiated with `use_distributions` set to `true`, replacing all histogram
# metrics with distribution metrics.
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

listener = Karafka::Instrumentation::Vendors::Datadog::MetricsListener.new do |config|
  config.client = statsd_dummy
  # Publish host as a tag alongside the rest of tags
  config.default_tags = ["host:#{Socket.gethostname}"]
  # Use distributions instead of histograms
  config.distribution_mode = :distribution
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && sleep(5)
end

%w[
  karafka.worker.processing
  karafka.worker.enqueued_jobs
  karafka.consumer.consumed.time_taken
  karafka.consumer.batch_size
  karafka.consumer.processing_lag
  karafka.consumer.consumption_lag
].each do |hist_key|
  assert_equal true, statsd_dummy.buffer[:distribution].key?(hist_key), "#{hist_key} missing"
end
