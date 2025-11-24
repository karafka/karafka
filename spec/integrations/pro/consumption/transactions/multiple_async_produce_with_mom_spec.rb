# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using transactions with multiple produce_async calls and manual offset management,
# we need to ensure that:
# 1. All async productions complete successfully before the transaction commits
# 2. The offset marking waits for all handlers
# 3. If any production fails, the entire transaction should roll back
#
# This test addresses the concern that mark_as_consumed might not wait for async handlers
# and could lead to skipped message processing if later productions fail.

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    transaction do
      messages.each do |message|
        # Produce async to multiple target topics
        DT[:handlers] << producer.produce_async(
          topic: DT.topics[1],
          payload: "target1_#{message.raw_payload}"
        )

        DT[:handlers] << producer.produce_async(
          topic: DT.topics[2],
          payload: "target2_#{message.raw_payload}"
        )

        DT[:handlers] << producer.produce_async(
          topic: DT.topics[3],
          payload: "target3_#{message.raw_payload}"
        )
      end

      # This should wait for all async handlers to complete before committing
      mark_as_consumed(messages.last)
    end

    DT[:done] = true
  end
end

class ValidationConsumer1 < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:target1] << msg.raw_payload }
  end
end

class ValidationConsumer2 < Karafka::BaseConsumer
  def consume
    messages.each { |msg| DT[:target2] << msg.raw_payload }
  end
end

class ValidationConsumer3 < Karafka::BaseConsumer
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
    consumer ValidationConsumer1
  end

  topic DT.topics[2] do
    consumer ValidationConsumer2
  end

  topic DT.topics[3] do
    consumer ValidationConsumer3
  end
end

# Produce 10 messages to the source topic
produce_many(DT.topics[0], DT.uuids(10))

start_karafka_and_wait_until do
  DT.key?(:done) &&
    DT[:target1].size >= 10 &&
    DT[:target2].size >= 10 &&
    DT[:target3].size >= 10
end

# Verify all handlers completed successfully
DT[:handlers].each do |handler|
  report = handler.wait
  assert report.error.nil?, "Handler should not have error: #{report.error}"
  assert report.offset >= 0, "Handler should have valid offset"
  assert report.partition >= 0, "Handler should have valid partition"
end

# Verify all messages were produced to all target topics
assert_equal 10, DT[:target1].size
assert_equal 10, DT[:target2].size
assert_equal 10, DT[:target3].size

# Verify the offset was committed correctly
assert_equal 10, fetch_next_offset

# Verify message content integrity
10.times do |i|
  assert DT[:target1].any? { |payload| payload.start_with?('target1_') }
  assert DT[:target2].any? { |payload| payload.start_with?('target2_') }
  assert DT[:target3].any? { |payload| payload.start_with?('target3_') }
end
