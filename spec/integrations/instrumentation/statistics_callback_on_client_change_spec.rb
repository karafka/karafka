# frozen_string_literal: true

# Karafka should not only recover from critical errors that happened but it also should reload
# the underlying client and keep publishing statistics from the new librdkafka client

setup_karafka(allow_errors: true)

draw_routes(Class.new, create_topics: false)

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
  sleep 1
end

# This will force listener to reload client (hacky, but works)
Karafka::App.monitor.subscribe('connection.listener.fetch_loop.received') do
  raise SuperException
end

Karafka::App.monitor.subscribe('statistics.emitted') do |event|
  DT[:stats_events] << event
end

start_karafka_and_wait_until do
  names(DT[:stats_events]).size >= 5
end

client_id = Karafka::App.config.client_id

previous_index = 0
names(DT[:stats_events]).each do |name|
  current_index = name.split('-').last.to_i
  assert previous_index < current_index
  assert name.start_with?(client_id)
  previous_index = current_index
end
