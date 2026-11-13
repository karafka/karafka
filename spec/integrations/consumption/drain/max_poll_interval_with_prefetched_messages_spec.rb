# frozen_string_literal: true

# When every batch takes most of `max.poll.interval.ms`, the poll and the drain of prefetched
# messages between batches should keep the consumer in the consumer group. It should not be kicked
# out, nothing should be revoked and all the messages should be consumed once and in order.
#
# A delay between the blocking poll and the drain makes the time between two blocking polls longer
# than `max.poll.interval.ms`, so only the drain, counting as a poll, keeps the consumer in.
#
# Small partition fetches and slow batches make librdkafka queue the messages before we poll again.

MAX_MESSAGES = 5
MESSAGES = 20

setup_karafka do |config|
  config.max_messages = MAX_MESSAGES
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  config.concurrency = 1
  config.shutdown_timeout = 60_000
end

module DrainDelay
  def drain(room)
    DT[:delayed] = true
    sleep(5)

    super
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(DrainDelay)

class Consumer < Karafka::BaseConsumer
  def consume
    # With the drain delay, more than the max poll interval passes between two blocking polls
    sleep(6)

    DT[:sizes] << messages.size
    messages.each { |message| DT[:offsets] << message.offset }
  end

  def revoked
    DT[:revoked] << partition
  end
end

# Shutdown also revokes, so only the ones while running count
Karafka.monitor.subscribe("rebalance.partitions_revoked") do
  DT[:revocations] << true if Karafka::App.running?
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(MESSAGES))

start_karafka_and_wait_until do
  DT[:offsets].size >= MESSAGES
end

# Without the drain hook running, this spec would not test anything
assert DT.key?(:delayed)
assert_equal (0...MESSAGES).to_a, DT[:offsets]
assert DT[:sizes].all? { |size| size <= MAX_MESSAGES }
assert DT[:revoked].empty?
assert DT[:revocations].empty?
