# frozen_string_literal: true

# Karafka should publish async errors from all the clients via a dedicated instrumentation hooks
# and they should not collide with each other.
# If they would, events would be published twice.

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

  consumer_group DataCollector.consumer_groups.last do
    topic DataCollector.topic do
      consumer Class.new
    end
  end
end

error_events = {}

Karafka::App.monitor.subscribe('error.emitted') do |event|
  error_events[event[:subscription_group_id]] ||= []
  error_events[event[:subscription_group_id]] << event
end

# Make sure that we have enough events from all the subscription groups
start_karafka_and_wait_until do
  error_events.size >= 2 &&
    error_events.values.all? { |errors| errors.size >= 2 }
end

unique = error_events
         .values
         .flatten
         .map { |event| event[:subscription_group_id] }
         .group_by(&:itself)
         .transform_values(&:count)

assert_equal 2, error_events.keys.size
# Each error published, should be published only once
assert_equal [2], unique.values.uniq
