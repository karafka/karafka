# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Here we subscribe to our listener and make sure nothing breaks during the notifications
# Majority of appsignal is tested in OSS so here we focus only on ticking that is a Pro feature
require 'karafka/instrumentation/vendors/appsignal/metrics_listener'
require 'karafka/instrumentation/vendors/appsignal/errors_listener'
require Karafka.gem_root.join('spec/support/vendors/appsignal/dummy_client')

# We allow errors to raise one to make sure things are published as expected
setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume; end

  def tick
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

metrics_listener = ::Karafka::Instrumentation::Vendors::Appsignal::MetricsListener.new do |config|
  config.client = appsignal_dummy
end

errors_listener = ::Karafka::Instrumentation::Vendors::Appsignal::ErrorsListener.new do |config|
  config.client = appsignal_dummy
end

Karafka.monitor.subscribe(metrics_listener)
Karafka.monitor.subscribe(errors_listener)

draw_routes do
  topic DT.topic do
    periodic interval: 100
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # This sleeps make karafka run a bit longer for more metrics to kick in
  DT[0].size >= 100 && sleep(5)
end

transactions_started = appsignal_dummy.buffer[:start_transaction].keys.uniq.sort

assert_equal transactions_started, %w[Consumer#consume Consumer#tick Consumer#shutdown].sort

# Error from ticking should be tracked
count_key = 'karafka_consumer_errors'
assert_equal true, appsignal_dummy.buffer[:count].key?(count_key), "#{count_key} missing"

assert_equal 1, appsignal_dummy.buffer[:errors].size
