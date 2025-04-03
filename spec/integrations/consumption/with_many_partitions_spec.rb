# frozen_string_literal: true

# Karafka should be able to consume messages from thousands of partitions
# Please note, that creating a topic with that many partitions can take few seconds

# This number should not go higher because slow CIs can be overloaded
PARTITIONS = 500

setup_karafka do |config|
  # We align this because creation of such huge topic on CI can take time
  config.admin.max_wait_time = 60_000 * 5
end

MUTEX = Mutex.new

DT[:data] = {}

class Consumer < Karafka::BaseConsumer
  def consume
    MUTEX.synchronize do
      messages.each do |message|
        DT[:data][partition] ||= []
        DT[:data][partition] << [message.partition, message.offset]
      end
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: PARTITIONS)
  end
end

messages = Array.new(PARTITIONS) do |i|
  [
    { topic: DT.topic, partition: i, payload: i.to_s },
    { topic: DT.topic, partition: i, payload: i.to_s }
  ]
end

Karafka.producer.produce_many_sync(messages.flatten)

start_karafka_and_wait_until do
  DT[:data].size >= PARTITIONS && DT[:data].values.flatten.size >= (PARTITIONS * 2)
end

DT[:data].each do |partition, offsets|
  assert_equal(
    offsets,
    [[partition, 0], [partition, 1]],
    "Partition: #{partition} offsets: #{offsets}"
  )
end
