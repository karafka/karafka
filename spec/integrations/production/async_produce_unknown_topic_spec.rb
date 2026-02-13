# frozen_string_literal: true

# This spec tests the behavior of produce_async when publishing to a non-existent topic
# Real-world scenario: After commit hooks in Rails using produce_async to unknown topics
#
# Questions answered by this test:
# 1. Can produce_async raise immediately? SOMETIMES - depends on cached metadata
#    - First attempt: May return handler (topic not yet in metadata cache)
#    - Second attempt: May raise immediately (topic known to be invalid)
# 2. Do messages queued BEFORE the unknown topic continue? YES - they succeed
# 3. Do messages queued AFTER the unknown topic continue? YES - they succeed
# 4. When is the error discovered? Either immediately OR during handler.wait()
#
# Key insight: The behavior varies based on librdkafka's metadata cache state

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

# Phase 2: Try producing to unknown topic (first attempt)
first_attempt_raised = false
handler_unknown_1 = nil

begin
  handler_unknown_1 = Karafka.producer.produce_async(
    topic: unknown_topic,
    payload: "first-message-to-unknown-topic"
  )
  DT[:first_attempt_succeeded] = true
rescue => e
  first_attempt_raised = true
  DT[:first_attempt_error] = e
  DT[:first_attempt_succeeded] = false
end

# Phase 2b: Try producing to unknown topic AGAIN (second attempt)
second_attempt_raised = false
handler_unknown_2 = nil

begin
  handler_unknown_2 = Karafka.producer.produce_async(
    topic: unknown_topic,
    payload: "second-message-to-unknown-topic"
  )
  DT[:second_attempt_succeeded] = true
rescue => e
  second_attempt_raised = true
  DT[:second_attempt_error] = e
  DT[:second_attempt_succeeded] = false
end

# Store information about what happened
DT[:first_raised] = first_attempt_raised
DT[:second_raised] = second_attempt_raised

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

# Collect all handlers (only add non-nil handlers)
all_handlers = [
  { handler: handler_before_1, label: "before-msg-1", phase: :before },
  { handler: handler_before_2, label: "before-msg-2", phase: :before },
  { handler: handler_after_1, label: "after-msg-1", phase: :after },
  { handler: handler_after_2, label: "after-msg-2", phase: :after },
  { handler: handler_after_3, label: "after-msg-3", phase: :after }
]

# Add unknown topic handlers only if they succeeded (didn't raise immediately)
if handler_unknown_1
  all_handlers << { handler: handler_unknown_1, label: "unknown-1", phase: :unknown }
end

if handler_unknown_2
  all_handlers << { handler: handler_unknown_2, label: "unknown-2", phase: :unknown }
end

# Track immediate exceptions separately (only if they actually raised)
# Note: We only add here if produce_async raised immediately (handler is nil)
# Otherwise, we'll add the async failure when we wait on the handler below
if !handler_unknown_1 && DT[:first_attempt_error]
  DT[:failed_messages] << {
    label: "unknown-1-immediate",
    topic: unknown_topic,
    error: DT[:first_attempt_error],
    code: :raised_immediately,
    phase: :unknown_immediate
  }
end

if !handler_unknown_2 && DT[:second_attempt_error]
  DT[:failed_messages] << {
    label: "unknown-2-immediate",
    topic: unknown_topic,
    error: DT[:second_attempt_error],
    code: :raised_immediately,
    phase: :unknown_immediate
  }
end

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

# Expected error codes for unknown topic (both immediate and async)
UNKNOWN_TOPIC_ERROR_CODES = %i[
  unknown_partition
  unknown_topic_or_part
  msg_timed_out
  raised_immediately
].freeze

# Count failures
unknown_failures = DT[:failed_messages].select { |m| m[:topic] == unknown_topic }
unknown_failures.select { |m| m[:code] == :raised_immediately }
unknown_failures.reject { |m| m[:code] == :raised_immediately }

# Assertion 1: At least one unknown topic message should have failed
assert unknown_failures.size >= 1, "At least one unknown topic message should fail"
assert(
  unknown_failures.size <= 2,
  "At most two unknown topic messages (tried twice), but got #{unknown_failures.size}: #{unknown_failures.map { |f| f[:label] }.join(", ")}"
)

# Assertion 2: Track what happened
# First attempt: either raised immediately or returned handler that failed
if DT[:first_raised]
  DT[:result] = "First attempt raised immediately: #{DT[:first_attempt_error].class}"
elsif handler_unknown_1
  DT[:result] = "First attempt returned handler (async failure)"
end

# Second attempt: likely raises immediately after first attempt metadata cached
if DT[:second_raised]
  DT[:result] = "#{DT[:result]} | Second attempt raised immediately: #{DT[:second_attempt_error].class}"
elsif handler_unknown_2
  DT[:result] = "#{DT[:result]} | Second attempt returned handler (async failure)"
end

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

# Assertion 5: Total delivery counts
total_failed = DT[:failed_messages].size
total_succeeded = DT[:successful_messages].size

assert total_failed >= 1, "Should have at least 1 failed delivery (unknown topic)"
assert total_failed <= 2, "Should have at most 2 failed deliveries (tried twice)"
assert_equal 5, total_succeeded, "Should have exactly 5 successful deliveries (valid topic)"
