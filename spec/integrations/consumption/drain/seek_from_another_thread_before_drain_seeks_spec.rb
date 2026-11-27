# frozen_string_literal: true

# A seek from another thread that lands after the drain took its messages and before the drain
# seeks a partition is newer than what the drain planned. Consumption should continue from the
# offset of that seek, not from the one the drain planned.
#
# A recreated topic resets its partitions back to the earliest offset, so the drain plans to seek
# them to right after their last drained message. We seek one of them back from another thread
# right before the drain seeks.

PARTITIONS = 4
BEFORE = 200
AFTER = 30
SEEK_TO = 0

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 50
  config.concurrency = 4
end

module SeekBeforeDrainSeeks
  private

  def seek_after_drain(rewinds, alignments)
    if DT.key?(:recreated) && !DT.key?(:planned) && alignments&.any?
      planned = alignments.first
      DT[:planned] = [planned.partition, planned.offset]

      Thread.new do
        seek(Karafka::Messages::Seek.new(planned.topic, planned.partition, SEEK_TO))
      end.join
    end

    super
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(SeekBeforeDrainSeeks)

class Consumer < Karafka::BaseConsumer
  def consume
    phase = DT.key?(:recreated) ? :after : :before

    # Lets librdkafka queue the messages of all the partitions after the reset
    if phase == :after && !DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    DT[[phase, partition]] << messages.map(&:offset)
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
  sleep(0.1) until PARTITIONS.times.all? do |partition|
    DT[[:before, partition]].flatten.size >= BEFORE
  end

  Karafka::Admin.delete_topic(DT.topic)
  Karafka::Admin.create_topic(DT.topic, PARTITIONS, 1)
  DT[:recreated] = true

  PARTITIONS.times do |partition|
    produce_many(DT.topic, DT.uuids(AFTER), partition: partition)
  end
end

start_karafka_and_wait_until do
  DT.key?(:planned) &&
    DT[[:after, DT[:planned].first]].flatten.last == AFTER - 1 &&
    sleep(5)
end

partition, planned_offset = DT[:planned]
batches = DT[[:after, partition]]
# The batch with the drained messages ends right before the offset the drain planned to seek to
last_drained = batches.index { |batch| batch.last == planned_offset - 1 }

assert SEEK_TO < planned_offset, DT[:planned]
assert !last_drained.nil?, batches
assert_equal (SEEK_TO...AFTER).to_a, batches[(last_drained + 1)..].flatten
