# frozen_string_literal: true

# This spec tests the behavior of produce_async when publishing to a non-existent topic
# Real-world scenario: After commit hooks in Rails using produce_async to unknown topics
#
# Questions answered by this test:
# 1. Is the exception raised immediately from produce_async call? NO - it returns a handler
# 2. Do messages queued BEFORE the unknown topic continue? YES - they succeed
# 3. Do messages queued AFTER the unknown topic continue? YES - they succeed
# 4. When is the error discovered? During handler.wait() or producer.close()

setup_karafka(allow_errors: true) do |config|
  # Disable auto-creation to ensure unknown topics fail
  config.kafka[:"allow.auto.create.topics"] = false
end

# Track errors from the producer
DT[:errors] = []
DT[:successful_messages] = []
DT[:failed_messages] = []

# Subscribe to producer error events
Karafka.producer.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << {
    type: event[:type],
    error: event[:error],
    code: event[:error]&.code
  }
end

# Create routing for topics (but don't activate them as we're just producing)
draw_routes do
  # Topic that will exist
  topic DT.topics[0] do
    active false
  end

  # Topic that won't exist (we'll reference a different topic)
  topic DT.topics[1] do
    active false
  end
end

# Non-existent topic (using a UUID to ensure it doesn't exist)
unknown_topic = "non-existent-topic-#{SecureRandom.uuid}"

# Valid topic (exists because draw_routes creates it)
valid_topic = DT.topics[0]

# Phase 1: Send messages to valid topic BEFORE the unknown topic message
# This simulates messages already queued before encountering the error
handler_before_1 = Karafka.producer.produce_async(
  topic: valid_topic,
  payload: "before-message-1"
)

handler_before_2 = Karafka.producer.produce_async(
  topic: valid_topic,
  payload: "before-message-2"
)

# Phase 2: Verify produce_async does NOT raise immediately for unknown topic
produce_async_raised = false

begin
  handler_unknown = Karafka.producer.produce_async(
    topic: unknown_topic,
    payload: "message-to-unknown-topic"
  )
rescue => e
  produce_async_raised = true
  DT[:immediate_exception] = e
end

# Assertion 1: produce_async should NOT raise immediately
assert !produce_async_raised, "produce_async raised immediately: #{DT[:immediate_exception]}"

# Phase 3: Send multiple messages to a valid topic AFTER the unknown topic message
# This simulates other messages being "in-flight" and tests if they continue
handler_after_1 = Karafka.producer.produce_async(
  topic: valid_topic,
  payload: "after-message-1"
)

handler_after_2 = Karafka.producer.produce_async(
  topic: valid_topic,
  payload: "after-message-2"
)

handler_after_3 = Karafka.producer.produce_async(
  topic: valid_topic,
  payload: "after-message-3"
)

# Phase 4: Wait for all handlers and check their results
# The error should be discovered during wait, not during produce_async

# Collect all handlers
all_handlers = [
  { handler: handler_before_1, label: "before-msg-1", phase: :before },
  { handler: handler_before_2, label: "before-msg-2", phase: :before },
  { handler: handler_unknown, label: "unknown-topic", phase: :unknown },
  { handler: handler_after_1, label: "after-msg-1", phase: :after },
  { handler: handler_after_2, label: "after-msg-2", phase: :after },
  { handler: handler_after_3, label: "after-msg-3", phase: :after }
]

# Wait for all handlers and categorize results
all_handlers.each do |h|
  result = h[:handler].wait(raise_response_error: false)

  if result.error
    DT[:failed_messages] << {
      label: h[:label],
      topic: ((h[:phase] == :unknown) ? unknown_topic : valid_topic),
      error: result.error,
      code: result.error.code,
      phase: h[:phase]
    }
  else
    DT[:successful_messages] << {
      label: h[:label],
      topic: ((h[:phase] == :unknown) ? unknown_topic : valid_topic),
      partition: result.partition,
      offset: result.offset,
      phase: h[:phase]
    }
  end
end

# Assertions

# Expected error codes for unknown topic
# Based on timing, librdkafka may return different error codes
UNKNOWN_TOPIC_ERROR_CODES = %i[unknown_partition unknown_topic_or_part msg_timed_out].freeze

# Assertion 2: Unknown topic message should have failed
unknown_failure = DT[:failed_messages].find { |m| m[:topic] == unknown_topic }
assert !unknown_failure.nil?, "Message to unknown topic should fail"
assert(
  UNKNOWN_TOPIC_ERROR_CODES.include?(unknown_failure[:code]),
  "Unknown topic should fail with expected error code, got: #{unknown_failure[:code]}"
)

# Assertion 3: All valid topic messages should have succeeded (both before and after)
valid_successes = DT[:successful_messages].select { |m| m[:topic] == valid_topic }
before_successes = valid_successes.select { |m| m[:phase] == :before }
after_successes = valid_successes.select { |m| m[:phase] == :after }

assert_equal 2, before_successes.size, "Messages queued BEFORE unknown topic should succeed"
assert_equal 3, after_successes.size, "Messages queued AFTER unknown topic should succeed"
assert_equal 5, valid_successes.size, "All 5 valid messages should succeed"

# Assertion 4: Valid messages should have valid offsets
valid_successes.each do |msg|
  assert msg[:offset] >= 0, "Valid message should have offset >= 0"
end

# Assertion 5: Exactly 1 failed and 5 successful deliveries
assert_equal 1, DT[:failed_messages].size, "Should have exactly 1 failed delivery"
assert_equal 5, DT[:successful_messages].size, "Should have exactly 5 successful deliveries"
