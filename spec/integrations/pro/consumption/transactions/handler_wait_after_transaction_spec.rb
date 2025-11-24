# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This test verifies the behavior when explicitly waiting on handlers after a transaction completes.
# Once the transaction block exits without error, the transaction is committed and handlers should
# indicate success, even if checked afterwards.
#
# This addresses the question: "Does this mean the transaction commits even if produce_async
# failed later on?" The answer should be: if the transaction block completed, all async
# operations have been acknowledged.
#
# Note: This spec works correctly regardless of how Kafka batches messages for delivery.

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 5
end

DT[:done] = false
DT[:transaction_committed] = false
DT[:handler_results] = []
DT[:received] = []

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT[:done]

    handlers = []

    transaction do
      messages.each do |message|
        handlers << producer.produce_async(
          topic: DT.topics[1],
          payload: "result_#{message.raw_payload}"
        )
      end

      mark_as_consumed(messages.last)
    end

    DT[:transaction_committed] = true

    handlers.each_with_index do |handler, index|
      result = handler.wait
      DT[:handler_results] << {
        index: index,
        error: result.error,
        offset: result.offset,
        partition: result.partition
      }
    end

    DT[:done] = true
  end
end

class ValidationConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:received] << msg.raw_payload }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    manual_offset_management true
  end

  topic DT.topics[1] do
    consumer ValidationConsumer
  end
end

produce_many(DT.topics[0], DT.uuids(5))

start_karafka_and_wait_until do
  DT[:done] && DT[:received].size >= 5
end

# Verify transaction committed
assert DT[:transaction_committed]

# Verify all handlers report successful delivery
assert_equal 5, DT[:handler_results].size
DT[:handler_results].each do |result|
  assert result[:error].nil?
  assert result[:offset] >= 0
  assert result[:partition] >= 0
end

# Verify all messages received
assert_equal 5, DT[:received].size

# Verify offset committed
assert_equal 5, fetch_next_offset
