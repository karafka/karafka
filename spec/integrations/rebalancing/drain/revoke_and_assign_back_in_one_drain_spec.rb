# frozen_string_literal: true

# When an eager rebalance revokes partitions and assigns some of them back inside one drain call,
# librdkafka is already past the messages drained for those partitions. Karafka removes them and
# should seek back, so no message is lost.
#
# Whether librdkafka returns messages after the assignment in that same drain depends on timing,
# so this spec checks continuity. The rewind itself is also covered by the client unit spec.
#
# Slow rebalance subscribers give librdkafka time to rejoin and fetch while the drain call is still
# serving the queue.

PARTITIONS = 4
PER_PARTITION = 2_000

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 200
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.kafka[:"partition.assignment.strategy"] = "range,roundrobin"
end

module DrainWindow
  def drain(room)
    # Widens the window between the blocking poll and the drain
    sleep(1) if DT.key?(:slow) && !DT.key?(:widened)
    DT[:widened] = true if DT.key?(:slow)

    super
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(DrainWindow)

Karafka.monitor.subscribe("rebalance.partitions_revoked") do
  sleep(5) if DT.key?(:slow)
end

Karafka.monitor.subscribe("rebalance.partitions_assigned") do
  sleep(5) if DT.key?(:slow)
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.5)

    messages.each do |message|
      return unless mark_as_consumed!(message)

      DT[:runs][[partition, object_id]] << message.offset
      DT[:all][partition] << message.offset
    end
  end
end

DT[:runs] = Hash.new { |h, k| h[k] = [] }
DT[:all] = Hash.new { |h, k| h[k] = [] }
DT[:other] = Hash.new { |h, k| h[k] = [] }

draw_topics do
  topic DT.topic do
    partitions PARTITIONS
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

PARTITIONS.times do |partition|
  produce_many(DT.topic, DT.uuids(PER_PARTITION), partition: partition)
end

other = Thread.new do
  sleep(0.1) until DT[:all].values.sum(&:size) >= 200

  DT[:slow] = true
  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)

  taken = 0
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 40

  while taken < 200 && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    message = consumer.poll(100)

    next unless message

    DT[:other][message.partition] << message.offset
    consumer.store_offset(message)
    taken += 1
  end

  consumer.commit(nil, false) if taken.positive?
  consumer.close
  DT.data.delete(:slow)

  DT[:other_done] = true
end

deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 120

start_karafka_and_wait_until do
  next true if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

  DT.key?(:other_done) &&
    PARTITIONS.times.all? do |partition|
      (DT[:all][partition] + DT[:other][partition]).uniq.size >= PER_PARTITION
    end
end

other.join

# Without the drain hook running, this spec would not test anything
assert DT.key?(:widened)

PARTITIONS.times do |partition|
  assert_equal(
    (0...PER_PARTITION).to_a,
    (DT[:all][partition] + DT[:other][partition]).uniq.sort
  )
end
