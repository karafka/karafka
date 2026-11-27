# frozen_string_literal: true

# With static membership (`group.instance.id`), a member that is stopped while librdkafka holds
# many prefetched messages and started again keeps its partition without a rebalance. Nothing past
# the last processed message may be committed on the stop, so after the restart the member should
# continue right after it, with no gap and no duplicate, and the other member should never get
# its partition. The drain takes many prefetched messages in one go, so the stop happens with a
# drained buffer.
#
# Small partition fetches and slow batches keep the librdkafka queue full.

PER_PARTITION = 2_000

setup_karafka do |config|
  config.kafka[:"group.instance.id"] = SecureRandom.hex(6)
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 100
end

module DrainTracker
  def poll_batch_nb(...)
    items = super
    DT[:drains] << items.size unless items.empty?
    items
  end
end

Rdkafka::Consumer.prepend(DrainTracker)

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.2)

    messages.each { |message| DT[partition] << message.offset }
  end
end

draw_topics do
  topic DT.topic do
    partitions 2
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
  end
end

Karafka.monitor.subscribe("rebalance.partitions_assigned") do
  DT[:assigned] = true
end

# Messages come only once both members are in, so each one consumes only its own partition
Thread.new do
  sleep(0.1) until DT.key?(:assigned)

  2.times do |partition|
    produce_many(DT.topic, DT.uuids(PER_PARTITION), partition: partition)
  end
end

# The other member joins first, so each member gets one partition when Karafka joins
other = Thread.new do
  consumer = setup_rdkafka_consumer("group.instance.id": SecureRandom.hex(6))
  consumer.subscribe(DT.topic)

  until DT.key?(:terminate)
    message = consumer.poll(100)

    DT[:other] << message.partition if message
  end

  consumer.close
end

sleep(10)

start_karafka_and_wait_until(reset_status: true) do
  [0, 1].any? { |partition| DT[partition].size >= 300 }
end

owned = [0, 1].find { |partition| DT[partition].size >= 300 }
DT[:stopped_at] = DT[owned].last

start_karafka_and_wait_until(reset_status: true) do
  DT[owned].last == PER_PARTITION - 1
end

DT[:terminate] = true
other.join

assert !DT[:drains].empty?
assert DT[:stopped_at] < PER_PARTITION - 1
# Static membership: the other member never gets the partition of the stopped one
assert !DT[:other].include?(owned)
assert_equal (0...PER_PARTITION).to_a, DT[owned]
