# frozen_string_literal: true

# Karafka should instrument prior to each consumer being enqueued

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(Consumer)

elements = DT.uuids(10)
produce_many(DT.topic, elements)

Karafka::App.monitor.subscribe('consumer.before_enqueue') do |event|
  DT[:events] << event[:caller]
end

start_karafka_and_wait_until do
  DT[:events].size >= 10
end

assert DT[:events].all? { |detail| detail.is_a?(Consumer) }
