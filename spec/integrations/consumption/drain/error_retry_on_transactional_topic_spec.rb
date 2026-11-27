# frozen_string_literal: true

# When a batch of a transactional topic with `read_committed` raises once, the partition is paused
# and sought back to the first message of that batch. After the retry, the partition comes back
# through a drain, and a transaction marker puts its position one past the last message. This is
# where the drain seeks in normal operation, so only the failed batch may be delivered again and
# nothing may be skipped after it.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again.

PARTITIONS = 3
PER_TRANSACTION = 20
TRANSACTIONS = 3

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.kafka[:"isolation.level"] = "read_committed"
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 10
  config.concurrency = 3
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
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    offsets = messages.map(&:offset)
    DT[partition] << offsets

    return unless partition.zero? && !DT.key?(:failed) && offsets.last > PER_TRANSACTION

    DT[:failed] = DT[partition].size - 1

    raise StandardError
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

# Each transaction takes its messages and one marker offset
TRANSACTIONS.times do
  Karafka::App.producer.transaction do
    PARTITIONS.times do |partition|
      messages = DT.uuids(PER_TRANSACTION).map do |payload|
        { topic: DT.topic, payload: payload, partition: partition }
      end

      Karafka::App.producer.produce_many_sync(messages)
    end
  end
end

expected = (0...TRANSACTIONS).flat_map do |transaction|
  start = transaction * (PER_TRANSACTION + 1)
  (start...(start + PER_TRANSACTION)).to_a
end

start_karafka_and_wait_until do
  PARTITIONS.times.all? { |partition| DT[partition].flatten.last == expected.last }
end

assert !DT[:drains].empty?

failed = DT[0][DT[:failed]]
# The retry starts at the first message of the failed batch
assert_equal failed.first, DT[0][DT[:failed] + 1].first

PARTITIONS.times do |partition|
  batches = DT[partition].dup
  batches.delete_at(DT[:failed]) if partition.zero?

  assert_equal expected, batches.flatten
end
