# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This test simulates the exact scenario described in the user's concern at scale:
# 1. Processing 5 batches, each with 3 messages (msg1, msg2, msg3)
# 2. Each message produces async to its own unique target topic
# 3. mark_as_consumed after all async productions
# 4. On first batch attempt, inject failure for msg2 (middle message)
#
# We verify that if the transaction completes without error, all async productions
# have been successfully acknowledged, so the callback cannot indicate failure later.
# This tests 15 total messages across 15 different topics.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 3
end

# Initialize counters and collections
DT[:batches_processed] = 0
DT[:first_batch_attempts] = 0
DT[:total_received] = 0
DT[:processing_order] = []
DT[:successful_batches] = []
DT[:failed_batches] = []
DT[:errors] = []
DT[:handler_statuses] = []
DT[:unexpected_failures] = []
DT[:received_by_topic] = Hash.new { |h, k| h[k] = [] }

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:batches_processed] += 1

    # Determine which batch we're actually processing based on offset
    batch_num = (messages.first.offset / 3) + 1

    # Only fail on the very first batch, first attempt
    should_fail = (batch_num == 1 && DT[:first_batch_attempts] == 0)
    DT[:first_batch_attempts] += 1 if batch_num == 1

    handlers = []

    begin
      transaction do
        messages.each_with_index do |message, index|
          msg_num = (batch_num - 1) * 3 + index
          DT[:processing_order] << "batch_#{batch_num}_msg_#{index}_attempt_#{should_fail ? 1 : 2}"

          # On first attempt of first batch only, inject a failure for the middle message
          if should_fail && batch_num == 1 && index == 1
            # This should cause the entire transaction to fail
            raise StandardError, 'Production failure for msg2 in first batch'
          end

          # Each message goes to its own unique target topic
          target_topic = DT.topics[msg_num + 1]

          handler = producer.produce_async(
            topic: target_topic,
            payload: "batch#{batch_num}_msg#{index}_#{message.raw_payload}"
          )

          handlers << {
            batch: batch_num,
            index: index,
            handler: handler,
            payload: message.raw_payload,
            target_topic: target_topic,
            msg_num: msg_num
          }
        end

        # This mark should only succeed if ALL async productions succeeded
        mark_as_consumed(messages.last)
      end

      # If we get here, transaction committed successfully
      DT[:successful_batches] << batch_num

      # Verify all handlers report success
      handlers.each do |handler_info|
        result = handler_info[:handler].wait

        DT[:handler_statuses] << {
          batch: handler_info[:batch],
          index: handler_info[:index],
          msg_num: handler_info[:msg_num],
          target_topic: handler_info[:target_topic],
          error: result.error,
          offset: result.offset,
          partition: result.partition,
          payload: handler_info[:payload]
        }

        # If transaction completed, all handlers MUST be delivered
        if result.error
          DT[:unexpected_failures] << {
            batch: handler_info[:batch],
            msg_num: handler_info[:msg_num],
            error: result.error
          }
        end
      end
    rescue StandardError => e
      DT[:failed_batches] << batch_num
      DT[:errors] << {
        batch: batch_num,
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

# Produce 15 messages (5 batches of 3 messages each)
# Each batch of 3 will be processed together
test_messages = []
5.times do |batch|
  3.times do |msg|
    test_messages << "batch#{batch}_msg#{msg}_#{DT.uuid}"
  end
end

produce_many(DT.topics[0], test_messages)

start_karafka_and_wait_until do
  # Wait for all 5 successful batches and all 15 messages received
  DT[:successful_batches].size >= 5 && DT[:total_received] >= 15
end

# Verify we processed exactly 5 batches (+ 1 retry for first batch)
assert_equal 6, DT[:batches_processed]

# Verify exactly 5 successful batches
assert_equal 5, DT[:successful_batches].size

# Verify first batch failed once
assert_equal 1, DT[:failed_batches].size
assert_equal 1, DT[:failed_batches].first

# Verify exactly one error
assert_equal 1, DT[:errors].size
assert_equal 1, DT[:errors].first[:batch]
assert DT[:errors].first[:message].include?('msg2')

# Verify all 15 messages were eventually produced and received
assert_equal 15, DT[:total_received]

# Verify each target topic received exactly one message
15.times do |i|
  topic_name = DT.topics[i + 1]
  messages = DT[:received_by_topic][topic_name]
  assert_equal 1, messages.size
end

# Verify all handlers from successful transactions report no errors
successful_handlers = DT[:handler_statuses]
assert_equal 15, successful_handlers.size

successful_handlers.each do |handler|
  assert handler[:error].nil?
  assert handler[:offset] >= 0
  assert handler[:partition] >= 0
end

# Verify no unexpected failures occurred after transaction commit
assert_equal 0, DT[:unexpected_failures].size

# Verify offset committed correctly (15 messages)
assert_equal 15, fetch_next_offset

# Verify processing order shows retry behavior for first batch only
first_batch_attempts = DT[:processing_order].select { |o| o.include?('batch_1_') }
assert first_batch_attempts.size >= 4

# Verify each batch produced to 3 different topics
batches_by_num = DT[:handler_statuses].group_by { |h| h[:batch] }
assert_equal 5, batches_by_num.size

batches_by_num.each do |batch_num, handlers|
  assert_equal 3, handlers.size

  # Verify each handler in batch went to a different topic
  topics = handlers.map { |h| h[:target_topic] }
  assert_equal 3, topics.uniq.size
end
