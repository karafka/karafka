# frozen_string_literal: true

# This spec tests the behavior of produce_async when publishing to a non-existent topic
# Real-world scenario: After commit hooks in Rails using produce_async to unknown topics
#
# Questions answered by this test:
# 1. Is the exception raised immediately from produce_async call? NO - it returns a handler
# 2. Do other in-flight messages continue to be published after an unknown topic error? YES
# 3. When is the error discovered? During handler.wait() or producer.close()

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

# Phase 1: Verify produce_async does NOT raise immediately for unknown topic
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

# Phase 2: Send multiple messages to a valid topic AFTER the unknown topic message
# This simulates other messages being "in-flight" and tests if they continue
handler_valid_1 = Karafka.producer.produce_async(
  topic: valid_topic,
  payload: "valid-message-1"
)

handler_valid_2 = Karafka.producer.produce_async(
  topic: valid_topic,
  payload: "valid-message-2"
)

handler_valid_3 = Karafka.producer.produce_async(
  topic: valid_topic,
  payload: "valid-message-3"
)

# Phase 3: Wait for all handlers and check their results
# The error should be discovered during wait, not during produce_async

# Check unknown topic message (should fail)
unknown_result = handler_unknown.wait(raise_response_error: false)

if unknown_result.error
  DT[:failed_messages] << {
    topic: unknown_topic,
    error: unknown_result.error,
    code: unknown_result.error.code
  }
else
  DT[:successful_messages] << {
    topic: unknown_topic,
    partition: unknown_result.partition,
    offset: unknown_result.offset
  }
end

# Check valid topic messages (should succeed)
[
  { handler: handler_valid_1, label: "valid-msg-1" },
  { handler: handler_valid_2, label: "valid-msg-2" },
  { handler: handler_valid_3, label: "valid-msg-3" }
].each do |h|
  result = h[:handler].wait(raise_response_error: false)

  if result.error
    DT[:failed_messages] << {
      label: h[:label],
      topic: valid_topic,
      error: result.error,
      code: result.error.code
    }
  else
    DT[:successful_messages] << {
      label: h[:label],
      topic: valid_topic,
      partition: result.partition,
      offset: result.offset
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

# Assertion 3: All valid topic messages should have succeeded
valid_successes = DT[:successful_messages].select { |m| m[:topic] == valid_topic }
assert_equal 3, valid_successes.size, "All 3 valid messages should succeed"

# Assertion 4: Valid messages should have valid offsets
valid_successes.each do |msg|
  assert msg[:offset] >= 0, "Valid message should have offset >= 0"
end

# Assertion 5: Exactly 1 failed and 3 successful deliveries
assert_equal 1, DT[:failed_messages].size, "Should have exactly 1 failed delivery"
assert_equal 3, DT[:successful_messages].size, "Should have exactly 3 successful deliveries"
