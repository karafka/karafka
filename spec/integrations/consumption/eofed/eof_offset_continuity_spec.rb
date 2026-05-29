# frozen_string_literal: true

# Regression test to ensure correct offset handling when EOF is reached and subsequent
# messages are produced, using the Eof polling strategy (enable.partition.eof = true).
#
# There is a known librdkafka bug in rd_kafka_consume_batch() where rd_kafka_position()
# can be incorrectly advanced by 2 after an EOF event:
# https://github.com/confluentinc/librdkafka/pull/5213
#
# The Eof polling strategy uses rd_kafka_consumer_poll (not rd_kafka_consume_batch).
# A companion test (consumption/offset_continuity_spec.rb) covers the Batch polling strategy
# path (rd_kafka_consume_batch_queue). This test verifies position tracking is correct
# in the Eof strategy path.
#
# Test scenario:
# 1. Produce 5 messages (offsets 0-4)
# 2. Consume all and reach EOF
# 3. Verify position is 5 (last consumed + 1)
# 4. Produce 1 more message (offset 5)
# 5. Verify all 6 messages are consumed with continuous offsets (0-5)

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.offset
      DT[:payloads] << message.raw_payload
    end

    # Run eofed in case it was not without messages
    eofed if eofed?
  end

  def eofed
    DT[:eof_count] << true

    # Only capture position and produce after all initial messages are consumed
    # This ensures the test works correctly even if messages arrive in multiple batches
    if DT[:consumed].size >= 5 && !DT.key?(:position_after_eof)
      # Get position using rdkafka position API
      # Use send to access the private method for testing
      DT[:position_after_eof] = client.send(:topic_partition_position, topic.name, partition)

      produce_many(topic.name, ["after_eof"])
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    eofed true
    deserializers(
      payload: ->(message) { message.raw_payload }
    )
  end
end

# Produce initial batch of messages
initial_messages = %w[msg0 msg1 msg2 msg3 msg4]
produce_many(DT.topic, initial_messages)

start_karafka_and_wait_until do
  # Wait until we've consumed all initial messages, hit EOF, and consumed the post-EOF message
  DT.key?(:eof_count) && DT[:eof_count].size >= 1 && DT[:consumed].size >= 6
end

# Verify position after EOF is correct (should be 5, which is last consumed offset 4 + 1)
# This verifies that rd_kafka_position() returns the correct value and wasn't affected by
# the double-increment bug
assert_equal 5, DT[:position_after_eof]

# Verify all messages were consumed
all_expected = initial_messages + ["after_eof"]
assert_equal all_expected, DT[:payloads]

# Verify offsets are continuous (0, 1, 2, 3, 4, 5)
expected_offsets = (0..5).to_a
assert_equal expected_offsets, DT[:consumed].sort.uniq
