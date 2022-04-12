# frozen_string_literal: true

# Karafka should publish same number of consumed events as batches consumed

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[0] << messages.count
  end
end

Karafka::App.monitor.subscribe('consumer.consumed') do |event|
  DataCollector.data[1] << event[:caller].messages.count
end

draw_routes do
  topic DataCollector.topic do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  produce(DataCollector.topic, rand.to_s)
  DataCollector.data[0].sum >= 100
end

assert_equal DataCollector.data[0], DataCollector.data[1]
