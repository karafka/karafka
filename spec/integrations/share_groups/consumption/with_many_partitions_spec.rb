# frozen_string_literal: true

# Share group (KIP-932) should be able to consume records from hundreds of partitions, getting
# every record once and attributing it to its real partition.

PARTITIONS = 200

setup_karafka do |config|
  # We align this because creation of such topic on CI can take time
  config.admin.max_wait_time = 60_000 * 5
end

MUTEX = Mutex.new

DT[:data] = {}

class Consumer < Karafka::ShareConsumer
  def consume
    MUTEX.synchronize do
      messages.each do |message|
        DT[:data][partition] ||= []
        DT[:data][partition] << [message.partition, message.offset]
      end
    end

    messages.each { |message| mark_as_accepted(message) }
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topic, DT.group, PARTITIONS)

messages = Array.new(PARTITIONS) do |i|
  [
    { topic: DT.topic, partition: i, payload: i.to_s },
    { topic: DT.topic, partition: i, payload: i.to_s }
  ]
end

Karafka.producer.produce_many_sync(messages.flatten)

start_karafka_and_wait_until do
  MUTEX.synchronize do
    DT[:data].size >= PARTITIONS && DT[:data].values.sum(&:size) >= (PARTITIONS * 2)
  end
end

assert_equal PARTITIONS, DT[:data].size

DT[:data].each do |partition, offsets|
  assert_equal(
    [[partition, 0], [partition, 1]],
    offsets.sort,
    "Partition: #{partition} offsets: #{offsets}"
  )
end
