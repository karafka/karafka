# frozen_string_literal: true

## DD instrumentation should work with eof

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
  config.kafka[:'enable.partition.eof'] = true
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def eofed
    DT[:eofed] = true

    raise
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
    eofed true
  end
end

Thread.new do
  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(2)
  rescue WaterDrop::Errors::ProducerClosedError
    nil
  end
end

start_karafka_and_wait_until do
  DT.key?(:eofed)
end

assert client.buffer.include?(['karafka.consumer', 'myservice-karafka']), client.buffer
assert client.buffer.include?('Consumer#eofed'), client.buffer
assert client.errors.any? { |error| error.is_a?(StandardError) }, client.errors
assert client.errors.all? { |error| error.is_a?(StandardError) }, client.errors

$stdout = proper_stdout
$stderr = proper_stderr

assert strio.string.include?('Eofed job for Consumer on')
assert strio.string.include?('Consumer eofed failed')
