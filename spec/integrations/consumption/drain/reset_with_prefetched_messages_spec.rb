# frozen_string_literal: true

# When an error in the poll resets the client while librdkafka holds prefetched messages and the
# committed offset is behind the last message handed over, consumption should resume from the
# committed offset of each partition and continue with no gap.
#
# Small partition fetches and slow batches make librdkafka queue the messages before we poll again.
# With two partitions, the first message of a partition after the reset can come from a drain, so
# the offset regression tracker must not keep offsets from before the reset.

PARTITIONS = 2
MESSAGES = 300
COMMITTED = 50

setup_karafka(allow_errors: %w[connection.listener.fetch_loop.error]) do |config|
  config.max_messages = 20
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
end

module PollFailure
  def batch_poll
    if DT.key?(:fail) && !DT.key?(:failed)
      DT[:failed] = true

      raise StandardError, "poll failure"
    end

    super
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(PollFailure)

Karafka.monitor.subscribe("client.reset") do
  DT[:resets] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.1)

    after_reset = DT.key?(:failed)

    messages.each do |message|
      DT[[after_reset ? :after : :before, partition]] << message.offset
      mark_as_consumed!(message) if after_reset || message.offset < COMMITTED
    end

    DT[:fail] = true if messages.last.offset >= COMMITTED + 40
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    config(partitions: PARTITIONS)
  end
end

PARTITIONS.times do |partition|
  produce_many(DT.topic, DT.uuids(MESSAGES), partition: partition)
end

start_karafka_and_wait_until do
  PARTITIONS.times.all? { |partition| DT[[:after, partition]].include?(MESSAGES - 1) }
end

assert_equal 1, DT[:resets].size
assert(PARTITIONS.times.any? { |partition| DT[[:before, partition]].last.to_i >= COMMITTED + 40 })

PARTITIONS.times do |partition|
  before = DT[[:before, partition]]
  committed = before.empty? ? 0 : [before.last + 1, COMMITTED].min

  assert_equal (0...before.size).to_a, before
  assert_equal (committed...MESSAGES).to_a, DT[[:after, partition]]
end
