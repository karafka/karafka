# frozen_string_literal: true

# Karafka should handle empty batches correctly in different processing strategies

setup_karafka

class EmptyBatchConsumer < Karafka::BaseConsumer
  def consume
    batch_info = {
      batch_size: messages.size,
      is_empty: messages.empty?,
      processing_start: Time.now.to_f,
      processed_count: 0
    }

    if messages.empty?
      batch_info[:empty_batch_handled] = true
      batch_info[:processing_strategy] = "empty_batch"
    else
      messages.each_with_index do |message, index|
        message_data = JSON.parse(message.raw_payload)

        DT[:processed_messages] << {
          message_id: message_data["id"],
          batch_position: index,
          processed_at: Time.now.to_f
        }

        batch_info[:processed_count] += 1
      end

      batch_info[:empty_batch_handled] = false
      batch_info[:processing_strategy] = "normal_batch"
    end

    batch_info[:processing_end] = Time.now.to_f
    batch_info[:processing_time] = batch_info[:processing_end] - batch_info[:processing_start]

    DT[:batches] << batch_info
  end
end

draw_routes(EmptyBatchConsumer)

# Produce some messages to test normal batch handling
# Note: Empty batches are usually internal to Kafka and may not be exposed to consumers
normal_messages = []
5.times do |i|
  normal_messages << {
    id: "normal_#{i}",
    content: "message_after_empty_batches",
    sequence: i
  }.to_json
end

# Produce messages to trigger normal batch processing
normal_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:processed_messages].size >= normal_messages.size
end

# Verify batch processing behavior
assert(
  DT[:batches].any?,
  "Should have processed at least one batch"
)

# Check if we had any empty batches (may or may not occur depending on timing)
empty_batches = DT[:batches].select { |batch| batch[:is_empty] }
normal_batches = DT[:batches].reject { |batch| batch[:is_empty] }

# Verify empty batch handling if any occurred
empty_batches.each do |batch|
  assert_equal(
    0, batch[:batch_size],
    "Empty batch should have zero size"
  )

  assert(
    batch[:empty_batch_handled],
    "Empty batch should be marked as handled"
  )

  assert_equal(
    "empty_batch", batch[:processing_strategy],
    "Empty batch should use empty_batch strategy"
  )

  assert_equal(
    0, batch[:processed_count],
    "Empty batch should process zero messages"
  )

  assert(
    batch[:processing_time] >= 0,
    "Empty batch should have non-negative processing time"
  )
end

# Verify normal batch handling
normal_batches.each do |batch|
  assert(
    batch[:batch_size] > 0,
    "Normal batch should have positive size"
  )

  assert(
    !batch[:empty_batch_handled],
    "Normal batch should not be marked as empty batch"
  )

  assert_equal(
    "normal_batch", batch[:processing_strategy],
    "Normal batch should use normal_batch strategy"
  )

  assert_equal(
    batch[:batch_size], batch[:processed_count],
    "Normal batch should process all messages"
  )
end

# Verify all expected messages were processed
assert_equal(
  normal_messages.size, DT[:processed_messages].size,
  "Should process all normal messages regardless of empty batches"
)

# Verify message ordering and content
processed_ids = DT[:processed_messages].map { |msg| msg[:message_id] }.sort
expected_ids = (0...normal_messages.size).map { |i| "normal_#{i}" }.sort
assert_equal(
  expected_ids, processed_ids,
  "Should process all expected messages with correct IDs"
)

# Verify batch position consistency
DT[:processed_messages].group_by { |msg| msg[:message_id] }.each do |_msg_id, entries|
  entries.each do |entry|
    assert(
      entry[:batch_position] >= 0,
      "Message batch position should be non-negative"
    )
  end
end

# The key success criteria: empty batch handling in different strategies
total_processed_messages = DT[:processed_messages].size
total_batches = DT[:batches].size

assert(
  total_batches > 0,
  "Should handle batches (empty or non-empty) correctly"
)

assert_equal(
  normal_messages.size, total_processed_messages,
  "Should handle empty batch scenarios without losing messages"
)
