# frozen_string_literal: true

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
    unless @raised
      @raised = true
      raise StandardError
    end

    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

client = Vendors::Datadog::LoggerDummyClient.new

listener = ::Karafka::Instrumentation::Vendors::Datadog::LoggerListener.new do |config|
  config.client = client
end

Karafka.monitor.subscribe(listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && sleep(5)
end

assert client.buffer.include?('karafka.consumer'), client.buffer
assert client.buffer.include?('Consumer#consume'), client.buffer
assert client.errors.any? { |error| error.is_a?(StandardError) }, client.errors
assert client.errors.all? { |error| error.is_a?(StandardError) }, client.errors

$stdout = proper_stdout
$stderr = proper_stderr

assert strio.string.include?('Consume job for Consumer on')
assert strio.string.include?('Consumer consuming error')
