# frozen_string_literal: true

# Karafka should handle various data serialization edge cases properly

setup_karafka

class SerializationEdgeCaseConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Track raw message processing - always available
      consumed_data = {
        raw_payload: message.raw_payload,
        size: message.raw_payload.bytesize,
        encoding: message.raw_payload.encoding.name
      }

      # Test JSON deserialization handling - some will fail
      begin
        # Try to parse as JSON
        parsed = JSON.parse(message.raw_payload)
        consumed_data[:parsed] = parsed
        consumed_data[:parseable] = true
      rescue JSON::ParserError => e
        consumed_data[:parseable] = false
        consumed_data[:parse_error] = e.class.name
      end

      DT[:consumed] << consumed_data
    end
  end
end

draw_routes(SerializationEdgeCaseConsumer)

# Test various serialization edge cases
edge_case_messages = [
  # Valid JSON
  { payload: '{}', description: 'empty_json' },
  { payload: '[]', description: 'empty_array' },
  { payload: 'null', description: 'json_null' },
  { payload: '{"data":"test"}', description: 'valid_json' },

  # Invalid JSON - should handle gracefully
  { payload: '', description: 'empty_message' },
  { payload: 'not json', description: 'plain_text' },
  { payload: "\x00\x01\x02\x03binary\xFF\xFE", description: 'binary_data' },

  # Edge case strings
  { payload: '9223372036854775807', description: 'number_as_string' },
  { payload: '"string with \\"quotes\\""', description: 'json_string_with_quotes' }
]

edge_case_messages.each do |msg_data|
  produce(DT.topic, msg_data[:payload])
end

start_karafka_and_wait_until do
  DT[:consumed].size >= edge_case_messages.size
end

# Verify all messages were consumed despite serialization edge cases
assert_equal(
  edge_case_messages.size, DT[:consumed].size,
  "Should consume all #{edge_case_messages.size} edge case messages"
)

# Verify each type of edge case was handled
empty_msg = DT[:consumed].find { |msg| msg[:size] == 0 }
assert !empty_msg.nil?

binary_msg = DT[:consumed].find { |msg| msg[:raw_payload] && msg[:raw_payload].include?("\x00") }
assert !binary_msg.nil?

# Verify some messages parsed successfully
parseable_messages = DT[:consumed].select { |msg| msg[:parseable] }
assert parseable_messages.size >= 4

# Verify some messages failed to parse but were still processed
unparseable_messages = DT[:consumed].reject { |msg| msg[:parseable] }
assert unparseable_messages.size >= 1

# Verify parse errors were caught
parse_errors = DT[:consumed].select { |msg| msg[:parse_error] }
assert parse_errors.any?

# Verify raw payloads are always preserved
assert(DT[:consumed].all? { |msg| msg[:raw_payload].is_a?(String) })

# Test encoding handling
encodings = DT[:consumed].map { |msg| msg[:encoding] }.uniq
assert encodings.any?

# The key success criteria: all edge case messages processed without consumer crash
assert_equal edge_case_messages.size, DT[:consumed].size
