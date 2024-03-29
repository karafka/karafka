# frozen_string_literal: true

# Karafka when started and stopped should go through all the lifecycle stages

# States changes that are published
PUBLISHED_STATES = %w[
  app.initialized
  app.running
  app.stopping
  app.stopped
].freeze

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

PUBLISHED_STATES.each_with_index do |state, index|
  assert_equal state, DT[:states][index]
end
