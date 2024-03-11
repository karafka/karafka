# frozen_string_literal: true

# Karafka should publish listener lifecyclce events

PUBLISHED_STATES = %w[
  connection.listener.pending
  connection.listener.starting
  connection.listener.running
  connection.listener.quieting
  connection.listener.quiet
  connection.listener.stopping
  connection.listener.stopped
]

PUBLISHED_STATES.each do |state|
  Karafka::App.monitor.subscribe(state) do
    DT[:states] << state
  end
end

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes(Consumer)

produce(DT.topic, '1')

start_karafka_and_wait_until do
  DT.key?(0)
end

# We need to sleep as state changes propagate in a separate thread
sleep(0.01) until DT[:states].size >= 4

assert (PUBLISHED_STATES - DT[:states]).empty?
