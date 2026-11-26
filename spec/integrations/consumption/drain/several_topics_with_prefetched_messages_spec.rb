# frozen_string_literal: true

# When one subscription group consumes several topics with the same partition numbers and drains
# prefetched messages of all of them in one batch, a pause on one topic and a seek on another
# should affect only their own partitions. Each partition should be consumed in order, with no gap,
# and the other topics should not be affected.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages of all the
# topics before we poll again, so the drains interleave them.

PARTITIONS = 2
MESSAGES = 300

setup_karafka do |config|
  config.max_messages = 100
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
end

module DrainTracker
  def drain(room, time_poll)
    DT[:drained] = true

    super
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(DrainTracker)

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each do |message|
      key = [topic.name, partition]

      if key == [DT.topics[0], 0] && message.offset == 100 && !DT.key?(:paused)
        DT[:paused] = true
        pause(message.offset, 1_000)

        return
      end

      if key == [DT.topics[1], 0] && message.offset == 80 && !DT.key?(:sought)
        DT[:sought] = true
        seek(20)

        return
      end

      DT[key] << message.offset
    end
  end
end

draw_topics do
  3.times do |index|
    topic DT.topics[index] do
      partitions PARTITIONS
    end
  end
end

draw_routes(create_topics: false) do
  3.times do |index|
    topic DT.topics[index] do
      consumer Consumer
    end
  end
end

3.times do |index|
  PARTITIONS.times do |partition|
    produce_many(DT.topics[index], DT.uuids(MESSAGES), partition: partition)
  end
end

keys = 3.times.to_a.product(PARTITIONS.times.to_a).map { |index, p| [DT.topics[index], p] }

start_karafka_and_wait_until do
  keys.all? { |key| DT[key].include?(MESSAGES - 1) }
end

# Without the drain hook running, this spec would not test anything
assert DT.key?(:drained)
assert DT.key?(:paused)
assert DT.key?(:sought)

# The seek goes back once, so its partition gets the sought range again, in order
assert_equal (0...80).to_a + (20...MESSAGES).to_a, DT[[DT.topics[1], 0]]

(keys - [[DT.topics[1], 0]]).each do |key|
  assert_equal (0...MESSAGES).to_a, DT[key]
end
