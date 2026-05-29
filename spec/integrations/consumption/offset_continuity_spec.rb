# frozen_string_literal: true

# Regression test for correct offset tracking in the Batch polling strategy
# (enable.partition.eof not set, uses rd_kafka_consume_batch_queue).
#
# There is a known librdkafka bug in rd_kafka_consume_batch() that incorrectly advances
# rd_kafka_position() by 2 after an EOF event:
# https://github.com/confluentinc/librdkafka/pull/5213
#
# Karafka's Batch polling strategy uses rd_kafka_consume_batch_queue (not rd_kafka_consume_batch),
# and the Eof strategy uses rd_kafka_consumer_poll. This test covers the Batch strategy path
# to confirm position tracking stays correct when messages arrive in separate waves.
#
# Test scenario:
# 1. Produce 5 messages (offsets 0-4)
# 2. Consume all
# 3. Verify position is 5 (last consumed + 1)
# 4. Produce 1 more message (offset 5)
# 5. Verify all 6 messages are consumed with continuous offsets (0-5)

setup_karafka do |config|
  config.max_messages = 10
  config.max_wait_time = 5_000
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.offset
      DT[:payloads] << message.raw_payload
    end

    return if DT[:consumed].size < 5
    return if DT.key?(:position_after_first_wave)

    DT[:position_after_first_wave] = client.send(:topic_partition_position, topic.name, partition)

    produce_many(topic.name, ["after_first_wave"])
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializers(
      payload: ->(message) { message.raw_payload }
    )
  end
end

produce_many(DT.topic, %w[msg0 msg1 msg2 msg3 msg4])

start_karafka_and_wait_until do
  DT.key?(:position_after_first_wave) && DT[:consumed].size >= 6
end

assert_equal 5, DT[:position_after_first_wave]
assert_equal %w[msg0 msg1 msg2 msg3 msg4 after_first_wave], DT[:payloads]
assert_equal (0..5).to_a, DT[:consumed].sort.uniq
