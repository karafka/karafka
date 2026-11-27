# frozen_string_literal: true

# When partitions are added to a topic while Karafka has many messages already prefetched, a
# cooperative-sticky rebalance only assigns the new partitions. The drain serves the rebalance
# callbacks in the middle of its call, so the assignment must not remove or skip the drained
# messages of the original partitions, and the new partitions must be consumed from their start.
#
# Small partition fetches and slow batches keep the librdkafka queue full, so the batches are
# mostly drained. Partitions are added while Karafka waits before a drain, so the assignment is
# queued by then and the drain serves it. Shorter waits follow until the assignment, in case it
# takes longer.

PARTITIONS = 2
ADDED = 2
PER_PARTITION = 1_000
PER_ADDED = 50

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 200
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.kafka[:"partition.assignment.strategy"] = "cooperative-sticky"
  config.kafka[:"topic.metadata.refresh.interval.ms"] = 1_000
end

module DrainWindow
  def drain(room, time_poll)
    callbacks = DT[:callbacks].size

    if DT.key?(:ready) && !DT.key?(:adding)
      DT[:adding] = true

      Karafka::Admin.create_partitions(DT.topic, PARTITIONS + ADDED)
      DT[:added] = true

      sleep(5)
    elsif waiting_for_assignment?
      sleep(2)
    end

    result = super

    DT[:in_drain_callbacks] << true if DT.key?(:adding) && DT[:callbacks].size > callbacks

    result
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(DrainWindow)

def waiting_for_assignment?
  DT.key?(:adding) && DT[:assignments].empty?
end

Karafka.monitor.subscribe("rebalance.partitions_revoked") do |event|
  DT[:callbacks] << true
  # Shutdown revokes everything, we only care about the rebalance
  DT[:revocations] << event[:tpl].to_h.values.flatten.size if Karafka::App.running?
end

Karafka.monitor.subscribe("rebalance.partitions_assigned") do
  DT[:callbacks] << true
  DT[:assignments] << true if DT.key?(:adding)
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Fast batches while we wait for the assignment, so the listener spends that time in the drain
    sleep(0.5) unless waiting_for_assignment?

    messages.each { |message| DT[:all][partition] << message.offset }
  end
end

DT[:all] = Hash.new { |h, k| h[k] = [] }

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
  produce_many(DT.topic, DT.uuids(PER_PARTITION), partition: partition)
end

Thread.new do
  sleep(0.1) until PARTITIONS.times.all? { |partition| DT[:all].fetch(partition, []).any? }

  DT[:ready] = true

  sleep(0.1) until DT.key?(:added)

  # The producer knows the new partitions only after its metadata refresh
  ADDED.times do |index|
    produce_many(DT.topic, DT.uuids(PER_ADDED), partition: PARTITIONS + index)
  rescue WaterDrop::Errors::ProduceManyError
    sleep(1)
    retry
  end
end

# A lost message would make us wait forever, so we stop and let the assertions fail
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 150

start_karafka_and_wait_until do
  next true if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

  PARTITIONS.times.all? { |partition| DT[:all].fetch(partition, []).size >= PER_PARTITION } &&
    ADDED.times.all? { |index| DT[:all].fetch(PARTITIONS + index, []).size >= PER_ADDED }
end

# Without a rebalance callback inside of a drain, this spec would not test anything
assert !DT[:in_drain_callbacks].empty?
# The rebalance only assigned
assert DT[:revocations].all?(&:zero?), DT[:revocations]

PARTITIONS.times do |partition|
  assert_equal (0...PER_PARTITION).to_a, DT[:all][partition]
end

ADDED.times do |index|
  assert_equal (0...PER_ADDED).to_a, DT[:all][PARTITIONS + index]
end
