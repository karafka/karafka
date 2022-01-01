# frozen_string_literal: true

# Karafka should publish async statistics from all the clients via a dedicated instrumentation
# hooks and they should not collide with each other.
# If they would, events would be published twice.

setup_karafka

draw_routes do
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

statistics_events = {}

Karafka::App.monitor.subscribe('statistics.emitted') do |event|
  statistics_events[event[:subscription_group_id]] ||= []
  statistics_events[event[:subscription_group_id]] << event
end

# Make sure that we have enough events from all the subscription groups
start_karafka_and_wait_until do
  statistics_events.size >= 2 &&
    statistics_events.values.all? { |stats| stats.size >= 2 }
end

# Within a single group, all events should come from the same client
statistics_events.each do |_group, stats|
  names = stats.map { |event| event[:statistics]['name'] }.uniq
  assert_equal 1, names.uniq.size
end

assert_equal 2, statistics_events.keys.size
