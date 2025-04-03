# frozen_string_literal: true

# Karafka should be able to consume messages from thousands of partitions
# Please note, that creating a topic with that many partitions can take few seconds

setup_karafka

MUTEX = Mutex.new

DT[:data] = {}

class Consumer < Karafka::BaseConsumer
  def consume
    MUTEX.synchronize do
      messages.each do |message|
        DT[:data][partition] ||= []
        DT[:data][partition] << message.offset
      end
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 1_000)
  end
end

messages = Array.new(1_000) do |i|
  [
    { topic: DT.topic, partition: i, payload: i.to_s },
    { topic: DT.topic, partition: i, payload: i.to_s }
  ]
end

Karafka.producer.produce_many_sync(messages.flatten)

start_karafka_and_wait_until do
  DT[:data].size >= 1_000 && DT[:data].values.flatten.size >= 2_000
end

DT[:data].each do |partition, offsets|
  assert_equal offsets, [0, 1], "Partition: #{partition} offsets: #{offsets}"
end
