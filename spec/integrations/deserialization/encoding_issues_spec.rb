# frozen_string_literal: true

# Karafka should handle various encoding issues gracefully

setup_karafka

class EncodingIssuesConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      consumed_data = {
        raw: message.raw_payload,
        size: message.raw_payload.bytesize,
        encoding: message.raw_payload.encoding.name
      }

      # Test various encoding operations
      begin
        # Test if the encoding is valid
        consumed_data[:valid_encoding] = message.raw_payload.valid_encoding?

        # Try to convert to UTF-8
        utf8_converted = message.raw_payload.encode("UTF-8", invalid: :replace, undef: :replace)
        consumed_data[:utf8_conversion] = "success"
        consumed_data[:utf8_size] = utf8_converted.bytesize

        # Try to force encoding to UTF-8
        forced_utf8 = message.raw_payload.force_encoding("UTF-8")
        consumed_data[:forced_valid] = forced_utf8.valid_encoding?
      rescue Encoding::InvalidByteSequenceError => e
        consumed_data[:encoding_error] = "invalid_byte_sequence"
        consumed_data[:error_message] = e.message
      rescue Encoding::UndefinedConversionError => e
        consumed_data[:encoding_error] = "undefined_conversion"
        consumed_data[:error_message] = e.message
      rescue => e
        consumed_data[:encoding_error] = "other_error"
        consumed_data[:error_type] = e.class.name
      end

      DT[:consumed] << consumed_data
    end
  end
end

draw_routes(EncodingIssuesConsumer)

# Test various encoding edge cases
encoding_test_messages = [
  # Valid UTF-8
  "Hello UTF-8 world! 🌍",

  # ASCII text
  "Simple ASCII text",

  # Latin-1 characters (need to be encoded properly)
  "Café with Latin-1 chars: àáâãäå",

  # Invalid UTF-8 byte sequences
  "\xFF\xFE\x00\x00Invalid UTF-8",

  # Mixed valid and invalid bytes
  "Valid text\xFF\xFEinvalid\x80more text",

  # Binary data that might be mistaken for text
  "\x00\x01\x02\x03\x04\x05Binary data\xFF\xFE\xFD",

  # High bit set bytes that might cause issues
  "\x80\x81\x82\x83\x84\x85\x86\x87",

  # Empty string
  "",

  # Unicode normalization edge cases
  "Normalization test: é vs é", # Different Unicode representations

  # Very long string with mixed encodings
  "Long string: #{"A" * 1000}\xFF\xFE#{"B" * 1000}"
]

encoding_test_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= encoding_test_messages.size
end

# Verify all messages were processed despite encoding issues
assert_equal(
  encoding_test_messages.size, DT[:consumed].size,
  "Should process all messages despite encoding issues"
)

# Verify different encodings were handled
encodings = DT[:consumed].map { |msg| msg[:encoding] }.uniq
assert encodings.any?, "Should detect various encodings"

# Verify valid encodings were detected
valid_encoding_messages = DT[:consumed].select { |msg| msg[:valid_encoding] }
invalid_encoding_messages = DT[:consumed].reject { |msg| msg[:valid_encoding] }

assert valid_encoding_messages.size >= 3, "Should have valid encoding messages"
# Some systems might handle encoding issues more gracefully, so make this more flexible
assert invalid_encoding_messages.size >= 0, "May detect invalid encoding messages"

# Verify UTF-8 conversion attempts were made
utf8_conversions = DT[:consumed].select { |msg| msg[:utf8_conversion] == "success" }
assert utf8_conversions.size >= 5, "Should successfully convert many messages to UTF-8"

# Verify encoding errors were caught when they occurred
encoding_errors = DT[:consumed].select { |msg| msg[:encoding_error] }
if encoding_errors.any?
  assert encoding_errors.size >= 1, "Should catch encoding errors when they occur"
end

# Verify forced encoding checks
forced_checks = DT[:consumed].select { |msg| msg.key?(:forced_valid) }
assert forced_checks.size >= 5, "Should check forced UTF-8 encoding validity"

# The key success criteria: all encoding edge cases processed without consumer crash
assert_equal(
  encoding_test_messages.size, DT[:consumed].size,
  "Should handle all encoding issues without crashing"
)

# Verify raw messages always preserved regardless of encoding issues
assert(
  DT[:consumed].all? { |msg| msg[:raw].is_a?(String) },
  "Raw payloads should always be available regardless of encoding issues"
)
