# frozen_string_literal: true

# Karafka should handle large nested objects and deep JSON structures

setup_karafka

class LargeNestedObjectsConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      consumed_data = {
        raw: message.raw_payload,
        size: message.raw_payload.bytesize
      }

      # Try to parse and measure JSON depth/size
      begin
        parsed = JSON.parse(message.raw_payload)
        consumed_data[:status] = 'valid_json'
        consumed_data[:parsed] = parsed

        # Measure nesting depth for objects
        if parsed.is_a?(Hash)
          consumed_data[:nesting_depth] = calculate_nesting_depth(parsed)
          consumed_data[:key_count] = count_all_keys(parsed)
        elsif parsed.is_a?(Array)
          consumed_data[:array_length] = parsed.length
          consumed_data[:nesting_depth] = calculate_array_depth(parsed)
        end
      rescue JSON::ParserError => e
        consumed_data[:status] = 'json_parse_error'
        consumed_data[:error_message] = e.message
      rescue SystemStackError
        consumed_data[:status] = 'stack_overflow'
        consumed_data[:error_message] = 'Stack level too deep'
      rescue StandardError => e
        consumed_data[:status] = 'other_error'
        consumed_data[:error_type] = e.class.name
      end

      DT[:consumed] << consumed_data
    end
  end

  private

  def calculate_nesting_depth(obj, current_depth = 0)
    return current_depth unless obj.is_a?(Hash) || obj.is_a?(Array)

    max_depth = current_depth
    if obj.is_a?(Hash)
      obj.each_value do |value|
        depth = calculate_nesting_depth(value, current_depth + 1)
        max_depth = [max_depth, depth].max
      end
    elsif obj.is_a?(Array)
      obj.each do |value|
        depth = calculate_nesting_depth(value, current_depth + 1)
        max_depth = [max_depth, depth].max
      end
    end

    max_depth
  end

  def calculate_array_depth(arr, current_depth = 0)
    return current_depth unless arr.is_a?(Array)

    max_depth = current_depth
    arr.each do |item|
      if item.is_a?(Array) || item.is_a?(Hash)
        depth = calculate_nesting_depth(item, current_depth + 1)
        max_depth = [max_depth, depth].max
      end
    end

    max_depth
  end

  def count_all_keys(obj)
    return 0 unless obj.is_a?(Hash)

    count = obj.size
    obj.each_value do |value|
      count += count_all_keys(value) if value.is_a?(Hash)
    end

    count
  end
end

draw_routes(LargeNestedObjectsConsumer)

# Create nested objects of varying complexity
def create_nested_object(depth)
  if depth <= 0
    "leaf_value_#{rand(1_000)}"
  else
    {
      "level_#{depth}" => create_nested_object(depth - 1),
      "data_#{depth}" => "value_at_level_#{depth}",
      "array_#{depth}" => (1..3).map { |i| "item_#{depth}_#{i}" }
    }
  end
end

def create_wide_object(width)
  obj = {}
  (1..width).each do |i|
    obj["key_#{i}"] = {
      "nested_#{i}" => {
        "deep_#{i}" => "value_#{i}",
        "array_#{i}" => (1..5).map { |j| "item_#{i}_#{j}" }
      }
    }
  end
  obj
end

# Test messages with various nesting scenarios
large_nested_messages = [
  # Simple nested object (baseline)
  '{"simple": {"nested": {"value": "test"}}}',

  # Deep nesting (reasonable depth)
  JSON.generate(create_nested_object(10)),

  # Wide object with many keys
  JSON.generate(create_wide_object(50)),

  # Large array with nested objects
  JSON.generate((1..100).map { |i| { "item_#{i}" => { 'data' => "value_#{i}" } } }),

  # Mixed deep and wide
  JSON.generate(
    {
      'root' => create_nested_object(8),
      'wide' => create_wide_object(20),
      'array' => (1..50).map { |_i| create_nested_object(3) }
    }
  ),

  # Very large string values in nested structure
  JSON.generate(
    {
      'large_data' => {
        'chunk1' => 'A' * 10_000,
        'nested' => {
          'chunk2' => 'B' * 10_000,
          'deep' => {
            'chunk3' => 'C' * 10_000
          }
        }
      }
    }
  )
]

large_nested_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= large_nested_messages.size
end

# Verify all messages were processed
assert_equal large_nested_messages.size, DT[:consumed].size,
             'Should process all large nested object messages'

# Verify JSON parsing succeeded for all messages
valid_json_messages = DT[:consumed].select { |msg| msg[:status] == 'valid_json' }
assert_equal large_nested_messages.size, valid_json_messages.size,
             'Should successfully parse all large nested JSON objects'

# Verify nesting depths were calculated
depth_measurements = DT[:consumed].select { |msg| msg[:nesting_depth] }
assert depth_measurements.size >= 4, 'Should measure nesting depth for complex objects'

# Verify at least one message has significant depth
deep_messages = DT[:consumed].select { |msg| msg[:nesting_depth] && msg[:nesting_depth] >= 8 }
assert deep_messages.size >= 1, 'Should handle deeply nested objects'

# Verify wide objects were processed
wide_messages = DT[:consumed].select { |msg| msg[:key_count] && msg[:key_count] >= 50 }
assert wide_messages.size >= 1, 'Should handle objects with many keys'

# Verify large arrays were processed
array_messages = DT[:consumed].select { |msg| msg[:array_length] && msg[:array_length] >= 50 }
assert array_messages.size >= 1, 'Should handle large arrays'

# Verify message sizes are substantial
large_messages = DT[:consumed].select { |msg| msg[:size] >= 10_000 }
assert large_messages.size >= 2, 'Should handle messages with substantial size'

# The key success criteria: all large nested objects processed without errors
assert_equal large_nested_messages.size, DT[:consumed].size,
             'Should handle all large nested objects without crashing'

# Verify no stack overflow or parsing errors occurred
error_messages = DT[:consumed].reject { |msg| msg[:status] == 'valid_json' }
assert error_messages.empty?, 'Should not encounter parsing errors with large nested objects'
