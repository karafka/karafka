# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This test verifies atomicity guarantees for large batch processing with many async productions.
# Ensures that even with hundreds of async produce operations, either all succeed or all fail
# together with the offset marking.
#
# Note: This spec works correctly regardless of how Kafka batches messages for delivery.

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 100
end

DT[:done] = false
DT[:total_handlers] = 0
DT[:processed_offsets] = []
DT[:handler_results] = []
DT[:target1] = []
DT[:target2] = []
DT[:target3] = []

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT[:done]

    handlers = []
    processed_offsets = []

    transaction do
      messages.each do |message|
        processed_offsets << message.offset

        DT.topics[1..3].each_with_index do |target_topic, topic_index|
          handler = producer.produce_async(
            topic: target_topic,
            key: message.key,
            payload: "topic#{topic_index}_offset#{message.offset}_#{message.raw_payload}",
            headers: {
              'source_offset' => message.offset.to_s,
              'target_topic_index' => topic_index.to_s
            }
          )

          handlers << {
            handler: handler,
            source_offset: message.offset,
            target_topic: target_topic,
            topic_index: topic_index
          }
        end
      end

      DT[:total_handlers] = handlers.size
      DT[:processed_offsets] = processed_offsets

      mark_as_consumed(messages.last)
    end

    handlers.each do |handler_info|
      result = handler_info[:handler].wait

      DT[:handler_results] << {
        error: result.error,
        source_offset: handler_info[:source_offset],
        target_topic: handler_info[:target_topic],
        topic_index: handler_info[:topic_index]
      }
    end

    DT[:done] = true
  end
end

class Target1Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:target1] << msg.raw_payload }
  end
end

class Target2Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:target2] << msg.raw_payload }
  end
end

class Target3Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:target3] << msg.raw_payload }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    manual_offset_management true
  end

  topic DT.topics[1] do
    consumer Target1Consumer
  end

  topic DT.topics[2] do
    consumer Target2Consumer
  end

  topic DT.topics[3] do
    consumer Target3Consumer
  end
end

message_count = 100
produce_many(DT.topics[0], DT.uuids(message_count))

start_karafka_and_wait_until do
  DT[:done] &&
    DT[:target1].size >= message_count &&
    DT[:target2].size >= message_count &&
    DT[:target3].size >= message_count
end

# Verify expected number of handlers (100 messages * 3 topics = 300)
assert_equal 300, DT[:total_handlers]

# Verify all handlers report successful delivery
assert_equal 300, DT[:handler_results].size
DT[:handler_results].each do |result|
  assert result[:error].nil?
end

# Verify all messages arrived at all target topics
assert_equal message_count, DT[:target1].size
assert_equal message_count, DT[:target2].size
assert_equal message_count, DT[:target3].size

# Verify message content format
DT[:target1].each { |msg| assert msg.start_with?('topic0_offset') }
DT[:target2].each { |msg| assert msg.start_with?('topic1_offset') }
DT[:target3].each { |msg| assert msg.start_with?('topic2_offset') }

# Verify offset committed
assert_equal message_count, fetch_next_offset

# Verify all expected offsets processed
assert_equal (0...message_count).to_a, DT[:processed_offsets].sort
