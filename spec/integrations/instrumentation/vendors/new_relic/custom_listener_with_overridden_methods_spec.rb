# frozen_string_literal: true

# The block form (`MetricsListener.new { |config| ... }`, aliased as #setup) is the documented way
# to configure the listener, and subclassing with partially overridden handlers is the documented
# way to suppress metrics you do not want.
#
# This asserts both work together: a custom namespace set through the block reaches every emitted
# metric name, handlers overridden with no-ops publish nothing, and handlers left alone still run
# through the parent implementation.
require "karafka/instrumentation/vendors/new_relic/metrics_listener"
require Karafka.gem_root.join("spec/support/vendors/new_relic/dummy_client")

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

# Suppresses the worker metrics while leaving consumption and statistics to the parent
class MinimalNewRelicListener < Karafka::Instrumentation::Vendors::NewRelic::MetricsListener
  def on_statistics_emitted(event)
    DT[:statistics_emitted_called] << event[:group_id]
    super
  end

  def on_worker_process(_event)
  end

  def on_worker_processed(_event)
  end

  def on_connection_listener_fetch_loop_received(_event)
  end
end

dummy_client = Vendors::NewRelic::DummyClient.new

listener = MinimalNewRelicListener.new do |config|
  config.client = dummy_client
  config.namespace = "custom_ns"
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[0].size >= 100 && sleep(5)
end

assert dummy_client.buffer.any?, "No metrics recorded at all"

# The namespace set through the configuration block must prefix every metric name
dummy_client.buffer.each_key do |key|
  assert(
    key.start_with?("Custom/custom_ns/"),
    "Expected #{key} to use the configured namespace"
  )
end

# Overridden handlers publish nothing
%w[
  worker.total_threads
  worker.processing
  worker.enqueued_jobs
].each do |fragment|
  offenders = dummy_client.buffer.keys.select { |key| key.include?(fragment) }

  assert_equal [], offenders, "#{fragment} was overridden with a no-op, got #{offenders}"
end

# Handlers left alone still run through the parent implementation
assert(
  DT[:statistics_emitted_called].any?,
  "on_statistics_emitted should still reach the parent implementation"
)

%w[
  consumer.messages
  consumer.batches
].each do |fragment|
  assert(
    dummy_client.buffer.keys.any? { |key| key.include?(fragment) },
    "#{fragment} should still be published - on_consumer_consumed was not overridden"
  )
end

# Statistics-derived metrics keep flowing too, since rd_kafka_metrics was left at its default
assert(
  dummy_client.buffer.keys.any? { |key| key.include?("consumer.lags") },
  "consumer.lags should still be published with the default rd_kafka_metrics"
)
