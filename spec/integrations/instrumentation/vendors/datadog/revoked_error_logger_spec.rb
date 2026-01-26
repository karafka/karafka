# frozen_string_literal: true

# Here we subscribe to our listener and make sure it properly handles consumer.revoked.error
# This error type was previously not explicitly handled and would have raised UnsupportedCaseError
# We use a dummy client that will intercept calls that should go to DataDog
# This test triggers a rebalance by exceeding the poll interval, which causes partition revocation
require "karafka/instrumentation/vendors/datadog/logger_listener"
require Karafka.gem_root.join("spec/support/vendors/datadog/logger_dummy_client")

strio = StringIO.new

proper_stdout = $stdout
proper_stderr = $stderr

$stdout = strio
$stderr = strio

# We allow errors to raise one to make sure things are published as expected
setup_karafka(allow_errors: %w[connection.client.poll.error consumer.revoked.error]) do |config|
  config.logger = Logger.new(strio)
  config.max_messages = 5
  # Set short poll interval to trigger revocation quickly
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  config.concurrency = 1
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume_count] << 1

    # Sleep long enough to exceed poll interval, triggering revocation
    sleep(15)

    DT[:done] << true
  end

  def revoked
    unless @raised
      @raised = true
      raise StandardError
    end

    DT[:revoked] = true
  end
end

client = Vendors::Datadog::LoggerDummyClient.new

listener = Karafka::Instrumentation::Vendors::Datadog::LoggerListener.new do |config|
  config.client = client
  config.service_name = "myservice-karafka"
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # Wait until we've had at least one revocation with the error and processed messages twice
  DT[:done].size >= 2
end

assert client.buffer.include?(["karafka.consumer", "myservice-karafka"]), client.buffer
assert client.errors.any?(StandardError), client.errors
assert client.errors.all?(StandardError), client.errors

$stdout = proper_stdout
$stderr = proper_stderr

assert strio.string.include?("Consume job for Consumer on")
assert strio.string.include?("Consumer on revoked failed due to an error")
# Verify DD listener handled the error type without raising UnsupportedCaseError
assert !strio.string.include?("UnsupportedCaseError"), strio.string
