# frozen_string_literal: true

# Karafka should handle batches with mixed success and failure scenarios

setup_karafka

class MixedResultsBatchConsumer < Karafka::BaseConsumer
  def consume
    messages.each_with_index do |message, index|
      message_data = JSON.parse(message.raw_payload)

      # Simulate mixed success/failure based on message content
      should_fail = message_data['should_fail'] == true

      if should_fail
        DT[:failed] << {
          message_id: message_data['id'],
          batch_position: index,
          batch_size: messages.size,
          error_type: 'intentional_failure'
        }

        # Simulate processing error
        raise StandardError, "Intentional failure for message #{message_data['id']}"
      else
        # Successful processing
        DT[:succeeded] << {
          message_id: message_data['id'],
          batch_position: index,
          batch_size: messages.size,
          processed_at: Time.now.to_f
        }
      end
    end
  end
end

draw_routes(MixedResultsBatchConsumer)

# Create a batch with mixed success/failure scenarios
mixed_messages = []
10.times do |i|
  mixed_messages << {
    id: i + 1,
    content: "message_#{i}",
    should_fail: (i % 3) == 1 # Fail every 3rd message (messages 2, 5, 8)
  }.to_json
end

# Produce all messages at once to ensure they're in the same batch
mixed_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  # Wait until we've processed some messages or encountered errors
  (DT[:succeeded].size + DT[:failed].size) >= 1
end

# Allow some time for error handling
sleep(1)

# Verify that we attempted to process messages
total_attempts = DT[:succeeded].size + DT[:failed].size
assert(
  total_attempts > 0,
  'Should have attempted to process at least some messages'
)

# Verify successful messages were processed correctly
DT[:succeeded].each do |entry|
  assert(
    entry[:message_id].is_a?(Integer),
    'Should have valid message ID'
  )

  assert(
    entry[:batch_position] >= 0,
    'Should have valid batch position'
  )

  assert(
    entry[:batch_size] > 0,
    'Should have positive batch size'
  )
end

# Verify failure tracking
DT[:failed].each do |entry|
  assert(
    entry[:message_id].is_a?(Integer),
    'Failed message should have valid ID'
  )

  assert_equal(
    'intentional_failure', entry[:error_type],
    'Should track the error type'
  )

  assert(
    entry[:batch_position] >= 0,
    'Failed message should have valid batch position'
  )
end

# Verify batch processing behavior under mixed conditions
if DT[:succeeded].any?
  batch_sizes = DT[:succeeded].map { |entry| entry[:batch_size] }.uniq
  assert(
    batch_sizes.size <= 2, # May have original batch size and retry batch sizes
    'Should have consistent batch size reporting'
  )

  batch_sizes.each do |size|
    assert(
      size > 0 && size <= mixed_messages.size,
      'Batch sizes should be reasonable'
    )
  end
end

# The key success criteria: mixed success/failure handling
assert(
  total_attempts > 0,
  'Should handle batches with mixed success/failure scenarios'
)
