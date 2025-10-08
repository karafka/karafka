# frozen_string_literal: true

# Karafka should handle malformed JSON gracefully without crashing

setup_karafka

# Custom JSON deserializer that gracefully handles malformed JSON
class SafeJsonDeserializer
  def call(message)
    result = {
      raw: message.raw_payload,
      size: message.raw_payload.bytesize
    }

    begin
      parsed = JSON.parse(message.raw_payload)
      result[:status] = 'valid_json'
      result[:parsed] = parsed
    rescue JSON::ParserError => e
      result[:status] = 'malformed_json'
      result[:error_type] = e.class.name
      result[:error_message] = e.message
    rescue StandardError => e
      result[:status] = 'other_error'
      result[:error_type] = e.class.name
    end

    result
  end
end

class MalformedJsonConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # The deserializer has already processed the JSON parsing and error handling
      consumed_data = message.payload
      DT[:consumed] << consumed_data
    end
  end
end

draw_routes do
  subscription_group do
    topic DT.topic do
      consumer MalformedJsonConsumer
      # Configure custom safe JSON deserializer
      deserializers(
        payload: SafeJsonDeserializer.new
      )
    end
  end
end

# Test various malformed JSON scenarios
malformed_messages = [
  # Valid JSON for contrast
  '{"valid": "json"}',
  # Missing closing brace
  '{"unclosed": "object"',
  # Trailing comma
  '{"trailing", "comma",}',
  # Unescaped quote
  '{"unescaped": "quote"inside"}',
  # Trailing comma in array
  '[1,2,3,]',
  # Missing value
  '{"key": }',
  # Unquoted key
  '{key: "value"}',
  # Nested malformed JSON
  '{"nested": {"broken": }',
  # Plain text
  'not json at all',
  # Empty string
  '',
  # Just opening brace
  '{',
  # Just closing brace
  '}',
  # Missing comma
  '{"key": "value" "another": "value"}',
  # Incomplete deep nesting
  '{"infinite": {"nesting": {"that": {"goes": {"very": {"deep": "value"}}}}}',
  # Invalid unicode escape
  '{"unicode": "\u004"}',
  # Invalid number format
  '{"number": 123.456.789}'
]

malformed_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= malformed_messages.size
end

# Verify all messages were processed despite malformed JSON
assert_equal malformed_messages.size, DT[:consumed].size

# Count different status types
valid_messages = DT[:consumed].select { |msg| msg[:status] == 'valid_json' }
malformed_messages_count = DT[:consumed].select { |msg| msg[:status] == 'malformed_json' }

# Verify at least one message was valid JSON
assert valid_messages.size >= 1, 'Should process valid JSON successfully'

# Verify malformed JSON was detected and handled
assert malformed_messages_count.size >= 10, 'Should detect multiple malformed JSON messages'

# Verify error details were captured
error_messages = DT[:consumed].select { |msg| msg[:error_message] }
assert error_messages.size >= 5, 'Should capture error details for malformed JSON'

# Verify specific error types were caught
error_types = DT[:consumed].map { |msg| msg[:error_type] }.compact.uniq
assert error_types.include?('JSON::ParserError'), 'Should catch JSON parsing errors'

# The key success criteria: all malformed JSON handled without consumer crashes
assert_equal malformed_messages.size, DT[:consumed].size

# Verify raw payloads are always preserved
assert(
  DT[:consumed].all? { |msg| msg[:raw].is_a?(String) },
  'Raw payloads should always be available regardless of JSON validity'
)
