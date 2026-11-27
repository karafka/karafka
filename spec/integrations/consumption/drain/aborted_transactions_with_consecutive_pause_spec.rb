# frozen_string_literal: true

# With committed and aborted transactions interleaved and `read_committed`, drained offsets have
# holes that are not from compaction. A pause without an offset in the middle of the flow must
# resume right after the last consumed message: no aborted message is consumed and no committed
# one is skipped or consumed twice. The drain moves the position only forward and checks drained
# offsets against the last ones handed over, so these holes must not look like a rewind.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again.

PER_TRANSACTION = 10
TRANSACTIONS = 8

setup_karafka do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.kafka[:"isolation.level"] = "read_committed"
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 15
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

    messages.each { |message| DT[:offsets] << message.offset }

    return if DT.key?(:paused) || messages.last.offset < PER_TRANSACTION * 3

    DT[:paused] = messages.last.offset
    pause(:consecutive, 1_000)
  end
end

draw_routes(Consumer)

# Even transactions are committed, odd ones aborted. Each one takes its messages and one marker
expected = []

TRANSACTIONS.times do |transaction|
  messages = DT.uuids(PER_TRANSACTION).map { |payload| { topic: DT.topic, payload: payload } }
  start = transaction * (PER_TRANSACTION + 1)

  Karafka::App.producer.transaction do
    Karafka::App.producer.produce_many_sync(messages)

    raise(WaterDrop::AbortTransaction) if transaction.odd?
  end

  expected += (start...(start + PER_TRANSACTION)).to_a if transaction.even?
end

start_karafka_and_wait_until do
  DT[:offsets].last == expected.last
end

assert !DT[:drains].empty?
assert DT.key?(:paused)
assert DT[:paused] < expected.last
assert_equal expected, DT[:offsets]
