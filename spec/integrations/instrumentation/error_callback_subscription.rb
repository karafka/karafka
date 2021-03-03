# frozen_string_literal: true

# Karafka should publish async errors from the client via a dedicated instrumentation hook

setup_karafka do |config|
  # Bad port on purpose to trigger the error
  config.kafka = { 'bootstrap.servers' => '127.0.0.1:9090' }
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_groups.first do
    topic DataCollector.topic do
      consumer Class.new
    end
  end
end

error_events = []

Karafka::App.monitor.subscribe('error.emitted') do |event|
  error_events << event
end

start_karafka_and_wait_until do
  !error_events.empty?
end

event = error_events.first

assert_not_equal 0, error_events.size
assert_equal true, event.is_a?(Dry::Events::Event)
assert_equal 'error.emitted', event.id
assert_equal true, event[:error].is_a?(Rdkafka::RdkafkaError)
assert_equal false, event[:subscription_group_id].empty?
# We remap the consumer group id to a consumer group, thus the raw name is just a part of the
# full name
assert_equal true, event[:consumer_group_id].include?(DataCollector.consumer_groups.first)
