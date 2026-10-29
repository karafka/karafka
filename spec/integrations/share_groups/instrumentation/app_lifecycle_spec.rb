# frozen_string_literal: true

# Share group (KIP-932) only routing: Karafka when started and stopped should go through all the
# app lifecycle stages in order.

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

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }
    DT[0] << true
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT.key?(0)
end

# We need to sleep as state changes propagate in a separate thread
sleep(0.01) until DT[:states].size >= 4

assert_equal PUBLISHED_STATES, DT[:states]
