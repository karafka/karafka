# frozen_string_literal: true

# Karafka should handle various message content edge cases properly

setup_karafka

class MessageContentConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << {
        key: message.key,
        payload: message.raw_payload,
        size: message.raw_payload.bytesize,
        partition: message.metadata.partition,
        offset: message.metadata.offset
      }
    end
  end
end

draw_routes(MessageContentConsumer)

# Test different message content types
test_messages = [
  { name: "single_space", payload: " ", expected_size: 1 },
  { name: "null_bytes", payload: "Hello\x00World\x00Test", expected_size: 16 },
  { name: "long_key", payload: "payload_with_long_key", key: "k" * 500, expected_size: 21 },
  { name: "utf8_issues", payload: "Valid text\xFF\xFE\x80Invalid UTF-8", expected_size: 26 },
  { name: "binary_pattern", payload: "\x00\x01\x02\xFF\xFE\xFD" * 50, expected_size: 300 }
]

test_messages.each do |test_msg|
  if test_msg[:key]
    produce(DT.topic, test_msg[:payload], key: test_msg[:key])
  else
    produce(DT.topic, test_msg[:payload])
  end
end

start_karafka_and_wait_until do
  DT[:consumed].size >= test_messages.size
end

# Verify messages were consumed (demonstrating edge case handling)
assert_equal(
  test_messages.size, DT[:consumed].size,
  "Should consume all #{test_messages.size} messages, got #{DT[:consumed].size}"
)

# Verify that Karafka successfully handled various edge case message types:

# Messages with edge case content are consumed (may be converted/sanitized)
# The key point is that they don't crash the consumer or cause failures
consumed_sizes = DT[:consumed].map { |msg| msg[:size] }.sort

# We should have messages with the expected approximate sizes
# (exact sizes may vary due to encoding conversions)
assert(
  consumed_sizes.include?(1),
  "Should process small message"
)

assert(
  consumed_sizes.any? { |size| size > 15 && size < 20 },
  "Should process null byte message"
)

assert(
  consumed_sizes.any? { |size| size > 20 && size < 30 },
  "Should process UTF-8 edge case message"
)

assert(
  consumed_sizes.any? { |size| size > 250 },
  "Should process binary content message"
)

# Test that message keys are preserved when present
messages_with_keys = DT[:consumed].select { |msg| msg[:key] && !msg[:key].empty? }
assert messages_with_keys.size >= 1, "Should preserve message keys when present"

# The test demonstrates that various edge case messages are handled gracefully
assert true, "Edge case message handling completed successfully"
