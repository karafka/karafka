# frozen_string_literal: true

# When a KIP-848 (`group.protocol: consumer`) rebalance revokes only some partitions while Karafka
# has many messages already prefetched, the kept partitions should be processed with no gap and no
# duplicates, and the new owner of the revoked ones should continue from the committed offset with
# no gap.
#
# Small partition fetches and slow batches keep the librdkafka queue full, so the batches are
# mostly drained. The second consumer joins while Karafka waits before a drain, so the revocation
# is queued by then and the drain serves it, not the listener between batches. Shorter waits
# follow until the first revocation, in case it takes longer.

PARTITIONS = 6
PER_PARTITION = 2_000

setup_karafka(consumer_group_protocol: true) do |config|
  config.concurrency = 2
  config.max_messages = 200
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
end

module DrainWindow
  def drain(room)
    callbacks = DT[:callbacks].size

    if DT.key?(:ready) && !DT.key?(:joining)
      DT[:joining] = true
      sleep(10)
    elsif waiting_for_revocation?
      sleep(2)
    end

    result = super

    DT[:in_drain_callbacks] << true if DT.key?(:joining) && DT[:callbacks].size > callbacks

    result
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(DrainWindow)

def waiting_for_revocation?
  DT.key?(:joining) && DT[:revocations].empty?
end

Karafka.monitor.subscribe("rebalance.partitions_revoked") do
  DT[:callbacks] << true
  DT[:revocations] << true
end

Karafka.monitor.subscribe("rebalance.partitions_assigned") do
  DT[:callbacks] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Fast batches while we wait for the revocation, so the listener spends that time in the drain
    sleep(0.5) unless waiting_for_revocation?

    messages.each do |message|
      DT[:runs][[partition, object_id]] << message.offset
      DT[:all][partition] << message.offset

      mark_as_consumed(message)
    end
  end
end

DT[:runs] = Hash.new { |h, k| h[k] = [] }
DT[:all] = Hash.new { |h, k| h[k] = [] }
DT[:other] = Hash.new { |h, k| h[k] = [] }
DT[:handover] = {}

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
  # Karafka should have consumed from all the partitions, so the revoked ones have queued data
  sleep(0.1) until PARTITIONS.times.all? { |partition| DT[:all].fetch(partition, []).any? }

  DT[:ready] = true
  sleep(0.1) until DT.key?(:joining)

  config = Karafka::Setup::AttributesMap.consumer(
    "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092"),
    "group.id": Karafka::App.routes.first.id,
    "group.protocol": "consumer",
    "auto.offset.reset": "earliest",
    "enable.auto.offset.store": "false"
  )

  consumer = Rdkafka::Config.new(config).consumer
  consumer.subscribe(DT.topic)

  taken = 0
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30

  while taken < 300 && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    message = consumer.poll(100)

    next unless message

    # Where Karafka was when it lost this partition
    DT[:handover][message.partition] ||= DT[:all].fetch(message.partition, [-1]).max

    DT[:other][message.partition] << message.offset
    consumer.store_offset(message)
    taken += 1
  end

  consumer.commit(nil, false) if taken.positive?
  consumer.close

  DT[:other_done] = true
end

# A lost message would make us wait forever, so we stop and let the assertions fail
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 150

start_karafka_and_wait_until do
  next true if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

  DT.key?(:other_done) &&
    PARTITIONS.times.all? do |partition|
      (DT[:all][partition] + DT[:other][partition]).uniq.size >= PER_PARTITION
    end
end

other.join

# Without a rebalance callback inside of a drain, this spec would not test anything
assert !DT[:in_drain_callbacks].empty?

taken_over = DT[:other].reject { |_, offsets| offsets.empty? }.keys

# Only part of the partitions was revoked
assert !taken_over.empty?
assert taken_over.size < PARTITIONS

PARTITIONS.times do |partition|
  assert_equal(
    (0...PER_PARTITION).to_a,
    (DT[:all][partition] + DT[:other][partition]).uniq.sort
  )
end

# The new owner continues from what Karafka committed, with no gap
taken_over.each do |partition|
  assert DT[:other][partition].first <= DT[:handover][partition] + 1
end

# The wait condition above creates empty lists for partitions the second consumer did not get
(DT[:runs].values + DT[:other].values).reject(&:empty?).each do |offsets|
  assert_equal (offsets.first..offsets.last).to_a, offsets
end
