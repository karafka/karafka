# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Here we subscribe to our listener and make sure nothing breaks during the notifications
# We use a dummy client that will intercept calls that should go to DataDog
require 'karafka/instrumentation/vendors/datadog/logger_listener'
require Karafka.gem_root.join('spec/support/vendors/datadog/logger_dummy_client')

strio = StringIO.new

proper_stdout = $stdout
proper_stderr = $stderr

$stdout = strio
$stderr = strio

# We allow errors to raise one to make sure things are published as expected
setup_karafka(allow_errors: true) do |config|
  config.logger = Logger.new(strio)
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end

  def tick
    unless @raised
      @raised = true
      raise StandardError
    end

    DT[:ticked] = true
  end
end

client = Vendors::Datadog::LoggerDummyClient.new

listener = Karafka::Instrumentation::Vendors::Datadog::LoggerListener.new do |config|
  config.client = client
  config.service_name = 'myservice-karafka'
end

Karafka.monitor.subscribe(listener)

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic interval: 1_000
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && DT.key?(:ticked) && sleep(5)
end

assert client.buffer.include?(['karafka.consumer', 'myservice-karafka']), client.buffer
assert client.buffer.include?('Consumer#tick'), client.buffer
assert client.errors.any?(StandardError), client.errors
assert client.errors.all?(StandardError), client.errors

$stdout = proper_stdout
$stderr = proper_stderr

assert strio.string.include?('Consume job for Consumer on')
assert strio.string.include?('Consumer on tick failed due to an error')
# Verify DD listener handled the error type without raising UnsupportedCaseError
assert !strio.string.include?('UnsupportedCaseError'), strio.string
