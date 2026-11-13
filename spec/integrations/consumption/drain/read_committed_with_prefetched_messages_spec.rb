# frozen_string_literal: true

# When committed and aborted transactions are already fetched, Karafka with `read_committed` should
# deliver only the committed messages, in order, skipping the aborted ones and the control
# records. After an aborted transaction at the end of the partition, the position should be past
# it, so the partition is not stuck.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again.

PER_TRANSACTION = 20

setup_karafka do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.kafka[:"isolation.level"] = "read_committed"
  config.kafka[:"enable.partition.eof"] = true
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each { |message| DT[:offsets] << message.offset }

    eofed if eofed?
  end

  def eofed
    return unless DT[:offsets].size >= PER_TRANSACTION * 2

    DT[:position] = fetch_position(client, topic.name, partition)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    eofed true
  end
end

def transaction(abort)
  messages = DT.uuids(PER_TRANSACTION).map { |payload| { topic: DT.topic, payload: payload } }

  Karafka::App.producer.transaction do
    Karafka::App.producer.produce_many_sync(messages)

    raise(WaterDrop::AbortTransaction) if abort
  end
end

# Offsets 0-19 (marker 20), aborted 21-40 (marker 41), 42-61 (marker 62), aborted 63-82 (marker 83)
transaction(false)
transaction(true)
transaction(false)
transaction(true)

start_karafka_and_wait_until do
  DT.key?(:position)
end

assert_equal (0..19).to_a + (42..61).to_a, DT[:offsets]
assert_equal 84, DT[:position]
