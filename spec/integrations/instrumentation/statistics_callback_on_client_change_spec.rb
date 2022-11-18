# frozen_string_literal: true

# Karafka should not only recover from critical errors that happened but it also should reload
# the underlying client and keep publishing statistics from the new librdkafka client

setup_karafka(allow_errors: true)

draw_routes(Class.new, create_topics: false)

stats_events = []

def names(stats_events)
  stats_events
    .map(&:payload)
    .map { |payload| payload[:statistics] }
    .map { |statistics| statistics.fetch('name') }
    .uniq
    .freeze
end

SuperException = Class.new(Exception)

Karafka::App.monitor.subscribe('connection.listener.before_fetch_loop') do
  # We sleep to make sure events from clients have time to be published
  sleep 0.5
end

# This will force listener to reload client (hacky, but works)
Karafka::App.monitor.subscribe('connection.listener.fetch_loop.received') do
  raise SuperException
end

Karafka::App.monitor.subscribe('statistics.emitted') do |event|
  stats_events << event
end

start_karafka_and_wait_until do
  names(stats_events).size >= 2
end

assert_equal %w[karafka#consumer-1 karafka#consumer-2 karafka#consumer-3], names(stats_events)
