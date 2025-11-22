# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This test verifies async production failure handling within transactions:
# 1. Produces 15 messages (offsets 0-14) to a topic
# 2. Each message produces async to its own unique target topic
# 3. mark_as_consumed is called after all async productions
# 4. On first attempt processing offset 1, inject a failure
#
# We verify that if the transaction completes without error, all async productions
# have been successfully acknowledged, so the callback cannot indicate failure later.
# This tests 15 total messages across 15 different topics.
#
# Note: This spec works correctly regardless of how Kafka batches messages for delivery.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 3
end

# Initialize counters and collections
DT[:consume_attempts] = 0
DT[:first_offset_attempts] = 0
DT[:total_received] = 0
DT[:processed_offsets] = []
DT[:successful_attempts] = []
DT[:failed_attempts] = []
DT[:errors] = []
DT[:handler_statuses] = []
DT[:unexpected_failures] = []
DT[:received_by_topic] = Hash.new { |h, k| h[k] = [] }

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume_attempts] += 1
    attempt_id = DT[:consume_attempts]

    # Track which offsets we're processing
    first_offset = messages.first.offset

    # Only fail on first time we see offset 0, and only on second message
    should_fail = (first_offset == 0 && DT[:first_offset_attempts] == 0)
    DT[:first_offset_attempts] += 1 if first_offset == 0

    handlers = []

    begin
      transaction do
        messages.each do |message|
          DT[:processed_offsets] << message.offset

          # On first attempt when starting from offset 0, inject a failure for offset 1
          if should_fail && message.offset == 1
            # This should cause the entire transaction to fail
            raise StandardError, 'Production failure for offset 1 in first attempt'
          end

          # Each message goes to its own unique target topic based on offset
          target_topic = DT.topics[message.offset + 1]

          handler = producer.produce_async(
            topic: target_topic,
            payload: "attempt#{attempt_id}_offset#{message.offset}_#{message.raw_payload}"
          )

          handlers << {
            attempt: attempt_id,
            offset: message.offset,
            handler: handler,
            payload: message.raw_payload,
            target_topic: target_topic
          }
        end

        # This mark should only succeed if ALL async productions succeeded
        mark_as_consumed(messages.last)
      end

      # If we get here, transaction committed successfully
      DT[:successful_attempts] << attempt_id

      # Verify all handlers report success
      handlers.each do |handler_info|
        result = handler_info[:handler].wait

        DT[:handler_statuses] << {
          attempt: handler_info[:attempt],
          offset: handler_info[:offset],
          target_topic: handler_info[:target_topic],
          error: result.error,
          result_offset: result.offset,
          partition: result.partition,
          payload: handler_info[:payload]
        }

        # If transaction completed, all handlers MUST be delivered
        if result.error
          DT[:unexpected_failures] << {
            attempt: handler_info[:attempt],
            offset: handler_info[:offset],
            error: result.error
          }
        end
      end
    rescue StandardError => e
      DT[:failed_attempts] << attempt_id
      DT[:errors] << {
        attempt: attempt_id,
        first_offset: first_offset,
        message: e.message
      }
      # Transaction rolled back, re-raise to trigger retry
      raise
    end
  end
end

class ValidationConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |msg|
      DT[:received_by_topic][topic.name] << msg.raw_payload
      DT[:total_received] += 1
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    manual_offset_management true
  end

  # Create 15 target topics (5 batches * 3 messages each)
  15.times do |i|
    topic DT.topics[i + 1] do
      consumer ValidationConsumer
    end
  end
end

# Produce 15 messages to the topic
# Kafka may deliver these in any batch size combination
test_messages = 15.times.map { |i| "msg#{i}_#{DT.uuid}" }

produce_many(DT.topics[0], test_messages)

start_karafka_and_wait_until do
  DT[:total_received] >= 15
end

# Verify at least one failed attempt
assert DT[:failed_attempts].size >= 1

# Verify exactly one error
assert_equal 1, DT[:errors].size
assert_equal 0, DT[:errors].first[:first_offset]
assert DT[:errors].first[:message].include?('offset 1')

# Verify all 15 messages were eventually produced and received
assert_equal 15, DT[:total_received]

# Verify each target topic received exactly one message
15.times do |i|
  topic_name = DT.topics[i + 1]
  messages = DT[:received_by_topic][topic_name]
  assert_equal 1, messages.size
end

# Verify all handlers from successful transactions report no errors
assert_equal 15, DT[:handler_statuses].size

DT[:handler_statuses].each do |handler|
  assert handler[:error].nil?
  assert handler[:result_offset] >= 0
  assert handler[:partition] >= 0
end

# Verify no unexpected failures occurred after transaction commit
assert_equal 0, DT[:unexpected_failures].size

# Verify offset committed correctly (15 messages)
assert_equal 15, fetch_next_offset

# Verify we processed offset 0 at least twice (initial fail + retry)
offset_0_attempts = DT[:processed_offsets].count(0)
assert offset_0_attempts >= 2

# Verify we processed offset 1 at least twice (failed on first, succeeded on retry)
offset_1_attempts = DT[:processed_offsets].count(1)
assert offset_1_attempts >= 2

# Verify offsets 2-14 were each processed at least once
(2..14).each do |offset|
  assert DT[:processed_offsets].include?(offset)
end
