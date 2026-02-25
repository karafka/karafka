# frozen_string_literal: true

# Here we ensure that our error tracker works as expected

require "karafka/instrumentation/vendors/appsignal/errors_listener"
require Karafka.gem_root.join("spec/support/vendors/appsignal/dummy_client")

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

appsignal_consumer_dummy = Vendors::Appsignal::DummyClient.new
appsignal_producer_dummy = Vendors::Appsignal::DummyClient.new

consumer_listener = Karafka::Instrumentation::Vendors::Appsignal::ErrorsListener.new do |config|
  config.client = appsignal_consumer_dummy
end

producer_listener = Karafka::Instrumentation::Vendors::Appsignal::ErrorsListener.new do |config|
  config.client = appsignal_producer_dummy
end

Karafka.monitor.subscribe(consumer_listener)
Karafka.producer.monitor.subscribe(producer_listener)

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && sleep(5)
end

assert_equal 1, appsignal_consumer_dummy.buffer[:errors].size
assert_equal 0, appsignal_producer_dummy.buffer[:errors].size
