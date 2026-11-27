# frozen_string_literal: true

# When a topic is recreated with `auto.offset.reset` set to `latest`, librdkafka resets its
# partitions to their end. When the first messages after that reset are drained, a
# `pause(:consecutive)` must still resume each partition right after its last consumed message:
# once consumption started after the reset, no message produced later may be skipped.
#
# Small partition fetches keep messages of many partitions queued, so later batches are drained.

PARTITIONS = 4
BEFORE = 100
AFTER = 100

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.kafka[:"auto.offset.reset"] = "latest"
  config.max_messages = 50
  config.concurrency = 4
end

class Consumer < Karafka::BaseConsumer
  def consume
    phase = DT.key?(:recreated) ? :after : :before

    pause(:consecutive, 100)

    position = fetch_position(client, topic.name, partition)
    DT[:positions] << [partition, messages.last.offset + 1, position] if phase == :after

    messages.each { |message| DT[[phase, partition]] << message.offset }
  end
end

draw_topics do
  topic DT.topic do
    partitions PARTITIONS
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
  end
end

def consumed?(phase, count)
  PARTITIONS.times.all? { |partition| DT[[phase, partition]].size >= count }
end

# Messages produced before librdkafka resets a partition to its end are skipped by design, so we
# keep producing and check only what comes after the first consumed message of each phase
producing = true

Thread.new do
  until consumed?(:after, AFTER)
    if producing
      PARTITIONS.times do |partition|
        produce_many(DT.topic, DT.uuids(5), partition: partition)
      end
    end

    sleep(0.05)
  end
end

Thread.new do
  sleep(0.1) until consumed?(:before, BEFORE)

  producing = false
  sleep(1)
  Karafka::Admin.delete_topic(DT.topic)
  Karafka::Admin.create_topic(DT.topic, PARTITIONS, 1)
  DT[:recreated] = true
  producing = true
end

start_karafka_and_wait_until do
  consumed?(:after, AFTER) && sleep(5)
end

PARTITIONS.times do |partition|
  %i[before after].each do |phase|
    offsets = DT[[phase, partition]]
    assert_equal (offsets.first..offsets.last).to_a, offsets, [phase, partition, offsets]
  end
end

# A seek clears the position (-1) until the next fetch, which then starts at the seek offset
DT[:positions].each do |partition, expected, position|
  assert [expected, -1].include?(position), [partition, DT[:positions]]
end
