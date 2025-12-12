# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This test verifies behavior when mixing synchronous and asynchronous productions
# within the same transaction. Both types should be properly handled and committed
# atomically together with offset marking.
#
# Note: This spec works correctly regardless of how Kafka batches messages for delivery.

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 10
end

DT[:done] = false
DT[:sync_count] = 0
DT[:async_count] = 0
DT[:sync_messages] = []
DT[:async_messages] = []

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT[:done]

    transaction do
      messages.each_with_index do |message, index|
        if index.even?
          producer.produce_sync(
            topic: DT.topics[1],
            payload: "sync_#{message.raw_payload}"
          )
          DT[:sync_count] += 1
        else
          producer.produce_async(
            topic: DT.topics[2],
            payload: "async_#{message.raw_payload}"
          )
          DT[:async_count] += 1
        end
      end

      mark_as_consumed(messages.last)
    end

    DT[:done] = true if DT[:sync_count] + DT[:async_count] >= 10
  end
end

class SyncConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:sync_messages] << msg.raw_payload }
  end
end

class AsyncConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:async_messages] << msg.raw_payload }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    manual_offset_management true
  end

  topic DT.topics[1] do
    consumer SyncConsumer
  end

  topic DT.topics[2] do
    consumer AsyncConsumer
  end
end

produce_many(DT.topics[0], DT.uuids(10))

start_karafka_and_wait_until do
  DT[:done] &&
    DT[:sync_messages].size >= 5 &&
    DT[:async_messages].size >= 5
end

# Verify counts
assert_equal 5, DT[:sync_count]
assert_equal 5, DT[:async_count]

# Verify messages received
assert_equal 5, DT[:sync_messages].size
assert_equal 5, DT[:async_messages].size

# Verify message prefixes
DT[:sync_messages].each { |msg| assert msg.start_with?('sync_') }
DT[:async_messages].each { |msg| assert msg.start_with?('async_') }

# Verify offset committed
assert_equal 10, fetch_next_offset
