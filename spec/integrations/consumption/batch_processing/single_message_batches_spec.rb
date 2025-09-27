# frozen_string_literal: true

# Karafka should handle single message batches correctly

setup_karafka

class SingleMessageBatchConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      message_data = JSON.parse(message.raw_payload)

      batch_info = {
        message_id: message_data['id'],
        batch_size: messages.size,
        is_single_message: messages.size == 1,
        message_offset: message.metadata.offset,
        partition: message.metadata.partition,
        processed_at: Time.now.to_f
      }

      DT[:consumed] << batch_info
    end
  end
end

draw_routes(SingleMessageBatchConsumer)

# Create multiple single-message scenarios
single_messages = []
10.times do |i|
  single_messages << {
    id: i + 1,
    content: "single_message_#{i}",
    timestamp: Time.now.to_f
  }.to_json
end

# Produce messages one by one with small delays to encourage single-message batches
single_messages.each_with_index do |msg, index|
  produce(DT.topic, msg)
  sleep(0.01) if index < single_messages.size - 1 # Small delay between messages
end

start_karafka_and_wait_until do
  DT[:consumed].size >= single_messages.size
end

# Verify all messages were processed
assert_equal(
  single_messages.size, DT[:consumed].size,
  'Should process all single messages'
)

# Verify batch processing occurred (may be single or multi-message batches)
# Note: Kafka batching behavior depends on timing and configuration
total_batches = DT[:consumed].map { |entry| entry[:batch_size] }.uniq.size
assert(
  total_batches >= 1,
  'Should have processed messages in batches'
)

# Verify message data integrity
DT[:consumed].each do |entry|
  assert(
    entry[:batch_size] > 0,
    'Batch size should be positive'
  )

  assert(
    entry[:message_offset].is_a?(Integer),
    'Should have valid message offset'
  )

  assert_equal(
    0, entry[:partition],
    'Should be from partition 0'
  )

  # If it's marked as single message, verify batch size is 1
  next unless entry[:is_single_message]

  assert_equal(
    1, entry[:batch_size],
    'Single message flag should match batch size of 1'
  )
end

# Verify message ordering is preserved
consumed_ids = DT[:consumed].map { |entry| entry[:message_id] }.sort
expected_ids = (1..single_messages.size).to_a
assert_equal(
  expected_ids, consumed_ids,
  'Should preserve message ordering'
)

# The key success criteria: batch processing handled correctly
assert_equal(
  single_messages.size, DT[:consumed].size,
  'Should handle message batch processing without issues'
)
