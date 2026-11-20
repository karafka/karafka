# frozen_string_literal: true

# When a topic is recreated, librdkafka resets its partitions back to the earliest offset. When
# the first messages after that reset are drained, a `pause(:consecutive)` must still resume each
# partition right after its last consumed message: no message may be consumed twice and the
# position of a paused partition must be right after the last consumed message.
#
# Small partition fetches keep messages of many partitions queued, so later batches are drained.

PARTITIONS = 4
BEFORE = 200
AFTER = 20

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
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

PARTITIONS.times do |partition|
  produce_many(DT.topic, DT.uuids(BEFORE), partition: partition)
end

Thread.new do
  sleep(0.1) until PARTITIONS.times.all? { |partition| DT[[:before, partition]].size >= BEFORE }

  Karafka::Admin.delete_topic(DT.topic)
  Karafka::Admin.create_topic(DT.topic, PARTITIONS, 1)
  DT[:recreated] = true

  PARTITIONS.times do |partition|
    produce_many(DT.topic, DT.uuids(AFTER), partition: partition)
  end
end

start_karafka_and_wait_until do
  PARTITIONS.times.all? { |partition| DT[[:after, partition]].size >= AFTER } &&
    sleep(5)
end

PARTITIONS.times do |partition|
  assert_equal (0...BEFORE).to_a, DT[[:before, partition]]
  assert_equal (0...AFTER).to_a, DT[[:after, partition]]
end

# A seek clears the position (-1) until the next fetch, which then starts at the seek offset
DT[:positions].each do |partition, expected, position|
  assert [expected, -1].include?(position), [partition, DT[:positions]]
end
