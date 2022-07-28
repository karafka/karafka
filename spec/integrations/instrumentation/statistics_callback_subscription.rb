# frozen_string_literal: true

# Karafka should publish async errors from the client via a dedicated instrumentation hook

setup_karafka

draw_routes(Class.new)

statistics_events = []

Karafka::App.monitor.subscribe('statistics.emitted') do |event|
  statistics_events << event
end

start_karafka_and_wait_until do
  !statistics_events.empty?
end

event = statistics_events.first

assert_not_equal 0, statistics_events.size
assert event.is_a?(::Karafka::Core::Monitoring::Event)
assert_equal 'statistics.emitted', event.id
assert_not_equal '', event[:subscription_group_id]
assert event[:consumer_group_id].include?(DataCollector.consumer_groups.first)
assert event[:statistics].is_a?(Hash)
assert_equal 0, event[:statistics]['txmsgs_d']
assert event[:statistics]['name'].include?('karafka')
