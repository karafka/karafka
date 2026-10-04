# frozen_string_literal: true

# Share group (KIP-932) with `consumer_persistence` enabled reuses one consumer instance per
# partition across all rounds and batches, while a topic with it disabled gets a new instance for
# every batch.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:instances] << [topic.name, messages.metadata.partition, object_id]

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      max_messages 3
      consumer Consumer
      consumer_persistence true
    end

    topic DT.topics[1] do
      max_messages 3
      consumer Consumer
      consumer_persistence false
    end
  end
end

setup_share_group(DT.topics[0], DT.group, 2)
setup_share_group(DT.topics[1], DT.group, 2)

2.times do |partition|
  produce_many(DT.topics[0], DT.uuids(10), partition: partition)
  produce_many(DT.topics[1], DT.uuids(10), partition: partition)
end

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 40
end

persistent, transient = DT[:instances].partition { |name, _, _| name == DT.topics[0] }

# One instance per partition, used for every batch of it, different between partitions
by_partition = persistent.group_by { |_, partition, _| partition }

assert_equal [0, 1], by_partition.keys.sort

by_partition.each_value do |instances|
  assert instances.size >= 4
  assert_equal 1, instances.map(&:last).uniq.size
end

assert_equal 2, persistent.map(&:last).uniq.size

# A new instance for every batch
assert transient.size >= 8
assert_equal transient.size, transient.map(&:last).uniq.size
