# frozen_string_literal: true

# Karafka should handle mixed serialization formats in a single topic

setup_karafka

# Custom deserializer that handles multiple formats
class MixedFormatDeserializer
  def call(message)
    raw_payload = message.raw_payload

    result = {
      raw: raw_payload,
      size: raw_payload.bytesize
    }

    # Try to detect and parse different formats
    format_detected = nil

    # Try JSON first
    begin
      parsed = JSON.parse(raw_payload)
      result[:parsed_as] = 'json'
      result[:parsed_value] = parsed
      format_detected = 'json'
    rescue JSON::ParserError
      # Not JSON, try other formats
    end

    # If not JSON, check if it's plain text
    if !format_detected && raw_payload.valid_encoding?
      if raw_payload.match?(/^\d+$/)
        result[:parsed_as] = 'numeric_string'
        result[:parsed_value] = raw_payload.to_i
        format_detected = 'numeric'
      elsif raw_payload.match?(/^[a-zA-Z\s]+$/)
        result[:parsed_as] = 'plain_text'
        result[:parsed_value] = raw_payload
        format_detected = 'text'
      end
    end

    # Check for binary data
    if !format_detected && raw_payload.include?("\x00")
      result[:parsed_as] = 'binary'
      result[:parsed_value] = raw_payload.bytes
    end

    # Fallback for unknown format
    result[:parsed_as] ||= 'unknown'

    result
  end
end

class MixedFormatConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # The deserializer has already processed the format detection
      consumed_data = message.payload
      DT[:consumed] << consumed_data
    end
  end
end

draw_routes do
  subscription_group do
    topic DT.topic do
      consumer MixedFormatConsumer
      # Configure custom mixed format deserializer
      deserializers(
        payload: MixedFormatDeserializer.new
      )
    end
  end
end

# Test various message formats in the same topic
mixed_messages = [
  # JSON object
  '{"type":"json","data":"test"}',

  # JSON array
  '["array", "of", "values"]',

  # Plain text
  'plain text message',

  # Numeric string
  '42',

  # Binary data
  "\x00\x01\x02\xFF\xFE",

  # XML-like text
  '<xml>data</xml>',

  # Query string format
  'key=value&other=data',

  # Multiline text
  "multi\nline\ntext",

  # Empty message
  ''
]

mixed_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= mixed_messages.size
end

# Verify all messages were consumed
assert_equal(
  mixed_messages.size, DT[:consumed].size,
  'Should consume all mixed format messages'
)

# Verify different formats were detected
formats_detected = DT[:consumed].map { |msg| msg[:parsed_as] }.uniq
assert formats_detected.include?('json'), 'Should detect JSON messages'
assert formats_detected.include?('plain_text'), 'Should detect plain text messages'
assert formats_detected.include?('binary'), 'Should detect binary data'
assert formats_detected.include?('unknown'), 'Should handle unknown formats'

# Verify JSON messages were parsed correctly
json_messages = DT[:consumed].select { |msg| msg[:parsed_as] == 'json' }
assert json_messages.size >= 2, 'Should parse at least 2 JSON messages'

# Verify binary data was handled
binary_messages = DT[:consumed].select { |msg| msg[:parsed_as] == 'binary' }
assert binary_messages.size >= 1, 'Should handle binary data'

# Verify unknown formats are also processed
unknown_messages = DT[:consumed].select { |msg| msg[:parsed_as] == 'unknown' }
assert unknown_messages.size >= 1, 'Should handle unknown format messages'

# The key test: all different formats processed without errors
assert_equal(
  mixed_messages.size, DT[:consumed].size,
  'Should handle all mixed formats in single topic'
)
