# frozen_string_literal: true

# Karafka should handle very small and very large batches efficiently

setup_karafka

class VariableBatchSizeConsumer < Karafka::BaseConsumer
  def consume
    batch_info = {
      batch_size: messages.size,
      processing_start: Time.now.to_f
    }

    processed_messages = []
    messages.each_with_index do |message, index|
      message_data = JSON.parse(message.raw_payload)

      processed_messages << {
        message_id: message_data["id"],
        batch_position: index,
        content_size: message.raw_payload.bytesize
      }
    end

    batch_info[:processing_end] = Time.now.to_f
    batch_info[:processing_time] = batch_info[:processing_end] - batch_info[:processing_start]
    batch_info[:messages] = processed_messages
    batch_info[:total_content_size] = processed_messages.sum { |m| m[:content_size] }

    DT[:batches] << batch_info
  end
end

draw_routes(VariableBatchSizeConsumer)

# Create small batches (produce with delays to separate batches)
3.times do |batch_num|
  2.times do |i|
    message = {
      id: "small_#{batch_num}_#{i}",
      content: "small_batch_message",
      batch_type: "small"
    }.to_json

    produce(DT.topic, message)
  end
  sleep(0.05) # Small delay to encourage separate batches
end

# Create one large batch (produce quickly to group together)
50.times do |i|
  message = {
    id: "large_#{i}",
    content: "large_batch_message_with_more_content_to_test_processing_performance",
    batch_type: "large",
    sequence: i
  }.to_json

  produce(DT.topic, message)
end

start_karafka_and_wait_until do
  total_messages = DT[:batches].sum { |batch| batch[:batch_size] }
  total_messages >= 56 # 6 small + 50 large messages
end

# Verify we processed the expected number of messages
total_processed = DT[:batches].sum { |batch| batch[:batch_size] }
assert(
  total_processed >= 56,
  "Should process all messages across different batch sizes"
)

# Analyze batch size distribution
batch_sizes = DT[:batches].map { |batch| batch[:batch_size] }
small_batches = batch_sizes.select { |size| size <= 5 }
large_batches = batch_sizes.select { |size| size > 5 }

assert(
  batch_sizes.any?,
  "Should have processed at least one batch"
)

# Verify batch processing performance characteristics and message ordering
DT[:batches].each do |batch|
  assert(
    batch[:processing_time] > 0,
    "Should record positive processing time"
  )

  assert(
    batch[:processing_time] < 1.0,
    "Processing should be reasonably fast (under 1 second)"
  )

  assert_equal(
    batch[:batch_size], batch[:messages].size,
    "Batch size should match number of processed messages"
  )

  assert(
    batch[:total_content_size] > 0,
    "Should calculate total content size"
  )

  # Verify message ordering within batches
  batch[:messages].each_with_index do |msg, index|
    assert_equal(
      index, msg[:batch_position],
      "Message positions should be sequential within batch"
    )
  end
end

# Performance analysis: larger batches might be more efficient per message
if large_batches.any? && small_batches.any?
  large_batch_info = DT[:batches].find { |batch| batch[:batch_size] > 5 }
  small_batch_info = DT[:batches].find { |batch| batch[:batch_size] <= 5 }

  if large_batch_info && small_batch_info
    large_per_msg_time = large_batch_info[:processing_time] / large_batch_info[:batch_size]
    small_per_msg_time = small_batch_info[:processing_time] / small_batch_info[:batch_size]

    # Both should be reasonable (under 100ms per message)
    assert(
      large_per_msg_time < 0.1,
      "Large batch per-message processing should be efficient"
    )

    assert(
      small_per_msg_time < 0.1,
      "Small batch per-message processing should be efficient"
    )
  end
end

# The key success criteria: variable batch sizes handled efficiently
assert(
  total_processed >= 56,
  "Should handle both small and large batches efficiently"
)
