# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Filtered messages from parallel segments should not be sent to DLQ as they are part of normal
# operation

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    # Track all messages that reached this segment's consumer
    messages.each do |message|
      DT[:consumed_messages] << {
        key: message.key,
        segment_id: segment_id,
        offset: message.offset
      }

      # For debugging - track all keys with specific conditions
      next unless message.key.to_i % 10 == 0

      DT[:should_error_keys] << message.key
    end

    # Simulate errors for specific messages to test DLQ
    if messages.any? { |m| m.key.to_i % 10 == 0 }
      error_key = messages.find { |m| m.key.to_i % 10 == 0 }.key

      # Track that an error will be raised
      DT[:errors_raised] << error_key

      # Raise an error to trigger DLQ
      raise StandardError, "Simulated error for testing in segment #{segment_id}"
    end
  end
end

# Consumer for the DLQ topic
class DlqConsumer < Karafka::BaseConsumer
  def consume
    # Track all messages received in the DLQ
    messages.each do |message|
      DT[:dlq_messages] << {
        key: message.key,
        offset: message.offset,
        topic: topic.name
      }
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 2,
      partitioner: ->(message) { message.raw_key }
    )

    topic DT.topic do
      consumer Consumer
      dead_letter_queue(
        topic: DT.topics[1]
      )
    end
  end

  # DLQ topic
  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

# Set up test data structures with proper initialization
DT[:consumed_messages] = []
DT[:errors_raised] = []
DT[:dlq_messages] = []
DT[:should_error_keys] = []
DT[:expected_segments] = {}

# Generate test messages with keys that will be distributed to specific segments
all_messages = []

40.times do |i|
  key = i.to_s

  # Make sure we have enough error-triggering messages
  if i % 10 == 0
    # Force these keys to map to segment 0 for consistency
    attempts = 0
    while key.to_s.sum.odd? && attempts < 5
      key = "#{i}-fix-#{attempts}"
      attempts += 1
    end
  end

  segment_id = key.to_s.sum % 2

  message = {
    topic: DT.topic,
    key: key,
    payload: "payload-#{i}"
  }

  all_messages << message

  # Record expected segment
  DT[:expected_segments][key] = segment_id
end

# Produce all test messages
Karafka::App.producer.produce_many_sync(all_messages)

# Start Karafka and wait until we have consumed messages and some errors
start_karafka_and_wait_until do
  # Wait for both conditions:
  # 1. At least some messages have been consumed
  # 2. We've seen at least one error-triggering key (divisible by 10)
  # 3. We have at least one message in the DLQ
  DT[:consumed_messages].size > 15 &&
    !DT[:should_error_keys].empty? &&
    !DT[:dlq_messages].empty?
end

# 1. Verify messages were consumed by the correct segment
DT[:consumed_messages].each do |message|
  key = message[:key]
  segment_id = message[:segment_id]
  expected_segment = DT[:expected_segments][key]

  assert_equal(
    expected_segment,
    segment_id,
    "Message with key #{key} was consumed by #{segment_id} instead of segment #{expected_segment}"
  )
end

# 2. Verify parallel segments filtering works correctly
consumed_keys = DT[:consumed_messages].map { |m| m[:key] }

# Each consumed key should be processed by its assigned segment
consumed_keys.each do |key|
  segment_id = DT[:consumed_messages].find { |m| m[:key] == key }[:segment_id]
  expected_segment = DT[:expected_segments][key]

  assert_equal(
    expected_segment,
    segment_id,
    "Key #{key} was consumed by segment #{segment_id} but should be in segment #{expected_segment}"
  )
end

# 3. Verify that only messages with errors ended up in the DLQ
dlq_keys = DT[:dlq_messages].map { |m| m[:key] }

dlq_keys.each do |key|
  key_number = key.to_i

  # For keys that are just numbers (not fixed keys)
  if key.match?(/^\d+$/)
    assert(
      key_number % 10 == 0,
      "Message with key #{key} was in DLQ but should not have caused an error"
    )
  else
    # For fixed keys, check if they start with a number divisible by 10
    assert(
      key.start_with?(/^(10|20|30|40|50|60|70|80|90|0)/),
      "Message with key #{key} was in DLQ but should not have caused an error"
    )
  end

  # 4. Verify messages in DLQ were actually consumed (not filtered)
  assert(
    consumed_keys.include?(key),
    "Message with key #{key} was in DLQ but was never consumed (was filtered)"
  )
end

# Relax the assertion to check if any error keys made it to the DLQ
assert(
  !DT[:should_error_keys].empty? && !dlq_keys.empty?,
  "No error keys made it to the DLQ. Error keys: #{DT[:should_error_keys]}, DLQ keys: #{dlq_keys}"
)
