# frozen_string_literal: true

# When an eager rebalance revokes caught-up partitions and assigns some of them back inside one
# drain call, the drain can hold only the eof of such a partition. Karafka should not crash on it
# or reset the client, and no message should be lost.
#
# Messages trickle into one partition, so blocking polls keep returning and drains keep running,
# while the other partitions are at eof. A wait before the drain queues up the revocation, and slow
# rebalance subscribers give librdkafka time to rejoin and fetch while the drain call is still
# serving the queue.

PARTITIONS = 4
PER_PARTITION = 100
TRICKLE = 300

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 200
  config.kafka[:"enable.partition.eof"] = true
  config.kafka[:"partition.assignment.strategy"] = "range,roundrobin"
end

module DrainWindow
  def drain(room)
    revocations = DT[:revocations].size
    assignments = DT[:assignments].size

    DT[:drained] = true

    # Until the first revocation, the rebalance events queue up while we wait here, so the drain
    # serves them
    sleep(1) if DT.key?(:slow) && DT[:revocations].empty?

    result = super

    if DT[:revocations].size > revocations && DT[:assignments].size > assignments
      DT[:in_drain_rebalances] << true
    end

    result
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(DrainWindow)

Karafka.monitor.subscribe("rebalance.partitions_revoked") do
  DT[:revocations] << true
  sleep(5) if DT.key?(:slow)
end

Karafka.monitor.subscribe("rebalance.partitions_assigned") do
  DT[:assignments] << true
  sleep(5) if DT.key?(:slow)
end

Karafka.monitor.subscribe("client.reset") do
  DT[:resets] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      return unless mark_as_consumed!(message)

      DT[:all][partition] << message.offset
    end
  end

  def eofed
    DT[:eofed] << partition
  end
end

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
    eofed true
    manual_offset_management true
  end
end

PARTITIONS.times do |partition|
  produce_many(DT.topic, DT.uuids(PER_PARTITION), partition: partition)
end

trickle = Thread.new do
  sleep(0.1) until DT[:eofed].uniq.size >= PARTITIONS - 1

  TRICKLE.times do
    produce(DT.topic, "1", partition: 0)
    sleep(0.05)
  end

  DT[:trickled] = true
end

other = Thread.new do
  sleep(0.1) until DT[:eofed].uniq.size >= PARTITIONS - 1
  sleep(1)

  DT[:slow] = true
  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)

  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20

  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    message = consumer.poll(100)

    next unless message

    DT[:other][message.partition] << message.offset
    consumer.store_offset(message)
  end

  consumer.commit(nil, false) unless DT[:other].empty?
  consumer.close
  DT.data.delete(:slow)

  DT[:other_done] = true
end

expected = Array.new(PARTITIONS) { PER_PARTITION }
expected[0] += TRICKLE

deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 120

start_karafka_and_wait_until do
  next true if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

  DT.key?(:other_done) &&
    DT.key?(:trickled) &&
    PARTITIONS.times.all? do |partition|
      (DT[:all][partition] + DT[:other][partition]).uniq.size >= expected[partition]
    end
end

other.join
trickle.join

# Without a revocation and an assignment inside of one drain, this spec would not test anything
assert DT.key?(:drained)
assert !DT[:in_drain_rebalances].empty?
assert DT[:resets].empty?

PARTITIONS.times do |partition|
  assert_equal(
    (0...expected[partition]).to_a,
    (DT[:all][partition] + DT[:other][partition]).uniq.sort
  )
end
