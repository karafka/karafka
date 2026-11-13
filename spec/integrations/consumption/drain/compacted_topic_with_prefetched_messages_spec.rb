# frozen_string_literal: true

# When a compacted topic has offset gaps and its messages are already fetched, Karafka should
# deliver every message that still exists, in order, and its position should not get stuck on a
# missing offset.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again.

KEYS = 10
ROUNDS = 10

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each { |message| DT[:offsets] << message.offset }

    eofed if eofed?
  end

  def eofed
    return unless DT[:offsets].last == DT[:existing].last

    DT[:position] = current_position
  end

  private

  def current_position
    tpl = Rdkafka::Consumer::TopicPartitionList.new(
      topic.name => [Rdkafka::Consumer::Partition.new(partition, nil, 0)]
    )

    client.wrapped_kafka.wrapped.position(tpl).to_h.fetch(topic.name).first.offset || -1
  end
end

Karafka::Admin.create_topic(
  DT.topic,
  1,
  1,
  "cleanup.policy": "compact",
  "segment.ms": 100,
  "min.cleanable.dirty.ratio": 0.001,
  "max.compaction.lag.ms": 100,
  "delete.retention.ms": 100
)

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
    eofed true
  end
end

# Every round overwrites the same keys in new segments, so compaction removes the older ones
ROUNDS.times do
  KEYS.times { |key| produce(DT.topic, DT.uuid, key: key.to_s) }
  sleep(0.2)
end

total = KEYS * ROUNDS
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 120

loop do
  # A new message rolls the active segment, so the previous ones can be compacted
  produce(DT.topic, DT.uuid, key: "roll")
  total += 1

  DT[:existing] = Karafka::Admin.read_topic(DT.topic, 0, total + 10, 0).map(&:offset)

  break if DT[:existing].first.to_i.positive? && DT[:existing].size < total / 2
  break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

  sleep(2)
end

existing = DT[:existing]

# Compaction left gaps
assert existing.size < total / 2

start_karafka_and_wait_until do
  DT.key?(:position)
end

# Compaction can go on while we consume, so later on fewer messages may exist than before
remaining = Karafka::Admin.read_topic(DT.topic, 0, total + 10, 0).map(&:offset)

assert_equal DT[:offsets].sort.uniq, DT[:offsets]
assert_equal [], remaining - DT[:offsets]
assert_equal [], DT[:offsets] - existing
assert_equal existing.last + 1, DT[:position]
