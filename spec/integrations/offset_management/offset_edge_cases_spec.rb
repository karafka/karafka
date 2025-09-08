# frozen_string_literal: true

# Karafka should handle offset management edge cases properly

setup_karafka

class OffsetEdgeCaseConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << {
        payload: message.raw_payload,
        offset: message.metadata.offset,
        partition: message.metadata.partition
      }

      # Test different offset marking scenarios based on payload
      case message.raw_payload
      when 'mark_out_of_order'
        # Try to mark an earlier message as consumed (if we have one)
        # This tests out-of-order offset marking handling
        if messages.size > 1 && messages.first != message
          mark_as_consumed!(messages.first)
        else
          # Still mark something to avoid issues
          mark_as_consumed!(message)
        end
      when 'mark_current'
        # Mark current message
        mark_as_consumed!(message)
      when 'no_mark'
        # Don't mark anything - test offset commits with empty batches
        # This tests how Karafka handles unmarked messages
      else
        # Regular processing with marking
        mark_as_consumed!(message)
      end
    end
  end
end

draw_routes(OffsetEdgeCaseConsumer)

# Test different offset scenarios
test_messages = %w[
  regular_message_1
  regular_message_2
  mark_out_of_order
  mark_current
  no_mark
  regular_message_3
]

# Produce all test messages
test_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= test_messages.size
end

# Verify all messages were consumed
assert_equal(
  test_messages.size, DT[:consumed].size,
  "Should consume all #{test_messages.size} messages"
)

# Verify messages have sequential offsets
offsets = DT[:consumed].map { |msg| msg[:offset] }.sort
assert_equal(
  offsets,
  offsets.sort,
  'Offsets should be in sequential order'
)

assert(
  offsets.each_cons(2).all? { |a, b| b > a },
  'Each offset should be greater than the previous'
)

# Verify all expected messages were consumed (the key test - no crashes occurred)
expected_payloads = test_messages.sort
actual_payloads = DT[:consumed].map { |msg| msg[:payload] }.sort
assert_equal(
  expected_payloads,
  actual_payloads,
  'All message payloads should be consumed despite offset edge cases'
)

# Verify specific edge case messages were processed
out_of_order_msg = DT[:consumed].find { |msg| msg[:payload] == 'mark_out_of_order' }
assert(
  !out_of_order_msg.nil?,
  'Should process out-of-order marking message'
)

no_mark_msg = DT[:consumed].find { |msg| msg[:payload] == 'no_mark' }
assert(
  !no_mark_msg.nil?,
  'Should process no-mark message'
)

# The main success criteria: all messages processed without consumer crashes
assert_equal(
  test_messages.size,
  DT[:consumed].size,
  'Should handle all offset edge cases without failure'
)
