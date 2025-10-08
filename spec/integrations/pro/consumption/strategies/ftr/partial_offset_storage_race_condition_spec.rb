# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Test for partial offset storage race condition in filtering API
# We mark the last removed message on a cursor but then mark ahead
# and check what is going to be marked to ensure proper offset management
# This tests the scenario where we have a cursor pointing to a removed message
# while also marking ahead of the cursor position

setup_karafka do |config|
  config.max_messages = 10
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.offset

      # Track batch boundaries
      DT[:batches] ||= []
      DT[:batches] << messages.map(&:offset)

      # Mark specific offsets to demonstrate marking behavior
      if message.offset == 3
        mark_as_consumed(message)
        DT[:marked] << message.offset
      elsif message.offset == 7
        # When processing offset 7, try to mark offset 9 ahead
        ahead_msg = messages.find { |m| m.offset == 9 }
        if ahead_msg
          mark_as_consumed(ahead_msg)
          DT[:marked] << ahead_msg.offset
          DT[:marked_ahead_from] = message.offset
        end
      end
    end
  end
end

# Filter that demonstrates race condition with cursor and marking
class CursorRaceFilter < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor

  def initialize
    super
    @processed_batches = 0
  end

  def apply!(messages)
    @processed_batches += 1

    # Apply filtering on first batch
    if @processed_batches == 1 && messages.any?
      # Track original messages
      DT[:original_batch1] = messages.map(&:offset)

      # Remove messages 4-6 from the first batch
      to_remove = messages.select { |m| m.offset.between?(4, 6) }

      if to_remove.any?
        # Set cursor to last removed message
        @cursor = to_remove.last
        DT[:cursor_offset] = @cursor.offset
        DT[:removed] = to_remove.map(&:offset)

        # Remove the messages
        to_remove.each { |msg| messages.delete(msg) }

        DT[:after_filtering] = messages.map(&:offset)
      end
    end
  end

  def applied?
    @cursor != nil
  end

  def action
    :skip
  end

  def timeout
    0
  end

  # Mark the cursor position (last removed message) as consumed
  def mark_as_consumed?
    @cursor != nil
  end

  def marking_method
    :mark_as_consumed!
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    filter ->(*) { CursorRaceFilter.new }
  end
end

# Produce messages
produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:consumed].size >= 17 # 20 total minus 3 filtered
end

# 1. Verify filter removed the expected messages
assert_equal [4, 5, 6], DT[:removed].sort, 'Should remove offsets 4-6'

# 2. Verify cursor was set to last removed offset
assert_equal 6, DT[:cursor_offset], 'Cursor should be set to offset 6 (last removed)'

# 3. Verify removed messages were not consumed
DT[:removed].each do |offset|
  assert !DT[:consumed].include?(offset), "Removed offset #{offset} should not be consumed"
end

# 4. Verify marking behavior
assert DT[:marked].include?(3), 'Offset 3 should be marked'
assert DT[:marked].include?(9), 'Offset 9 should be marked ahead'

# 5. Verify marking ahead happened from offset 7
assert_equal 7, DT[:marked_ahead_from], 'Marking ahead should happen from offset 7'

# 6. Ensure correct offsets were consumed (all except removed)
expected_consumed = (0..19).to_a - [4, 5, 6]
assert_equal expected_consumed, DT[:consumed].sort, 'Should consume all except filtered offsets'

# 7. Verify no duplicate consumption
assert_equal DT[:consumed].uniq.size, DT[:consumed].size, 'No duplicate consumption'
