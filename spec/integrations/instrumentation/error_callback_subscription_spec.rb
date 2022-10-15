# frozen_string_literal: true

# Karafka should publish async errors from the client via a dedicated instrumentation hook

setup_karafka(allow_errors: true) do |config|
  # Bad port on purpose to trigger the error
  config.kafka = { 'bootstrap.servers': '127.0.0.1:9090' }
end

draw_routes(Class.new)

error_events = []

Karafka::App.monitor.subscribe('error.occurred') do |event|
  error_events << event
end

start_karafka_and_wait_until do
  !error_events.empty?
end

event = error_events.first

assert_not_equal 0, error_events.size
assert event.is_a?(Karafka::Core::Monitoring::Event)
assert_equal 'error.occurred', event.id
assert_equal 'librdkafka.error', event[:type]
assert event[:error].is_a?(Rdkafka::RdkafkaError)
assert_equal false, event[:subscription_group_id].empty?
# We remap the consumer group id to a consumer group, thus the raw name is just a part of the
# full name
assert event[:consumer_group_id].include?(DT.consumer_groups.first)
