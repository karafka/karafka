# frozen_string_literal: true

# When messages and eof events of many partitions are already fetched, Karafka takes them in one
# go after the first poll. Every message should be consumed once and in order, each partition
# should reach eof, and the position after eof should not be moved past the last message.
#
# Small partition fetches and a slow first batch make librdkafka queue the rest of the messages
# with the eof events between them before we poll again.

PARTITIONS = 3
PER_PARTITION = 100

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each { |message| DT[partition] << message.offset }

    eofed if eofed?
  end

  def eofed
    return unless DT[partition].size >= PER_PARTITION
    return if DT[:positions].key?(partition)

    DT[:positions][partition] = current_position
  end

  private

  def current_position
    tpl = Rdkafka::Consumer::TopicPartitionList.new(
      topic.name => [Rdkafka::Consumer::Partition.new(partition, nil, 0)]
    )

    client.wrapped_kafka.wrapped.position(tpl).to_h.fetch(topic.name).first.offset || -1
  end
end

DT[:positions] = {}

draw_topics do
  topic DT.topic do
    partitions PARTITIONS
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
    eofed true
  end
end

PARTITIONS.times do |partition|
  produce_many(DT.topic, DT.uuids(PER_PARTITION), partition: partition)
end

start_karafka_and_wait_until do
  DT[:positions].size >= PARTITIONS
end

PARTITIONS.times do |partition|
  assert_equal (0...PER_PARTITION).to_a, DT[partition]
  assert_equal PER_PARTITION, DT[:positions][partition]
end
