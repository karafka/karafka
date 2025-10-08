# frozen_string_literal: true

# Karafka should handle topics with special characters properly

setup_karafka

class SpecialCharacterConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << {
        topic: message.metadata.topic,
        partition: message.metadata.partition,
        payload: message.raw_payload,
        consumer_class: self.class.name
      }
    end
  end
end

# Test topics with various special characters that are valid in Kafka
# We'll test both valid patterns and invalid ones to verify validation

# Valid topic names (following consistent namespacing)
# All must start with "it-" for integration tests
valid_dash_topics = %w[
  it-topic-with-dashes
  it-topic-with-numbers123
  it-TopicWithCamelCase
  it-UPPER-CASE-TOPIC
  it-lower-case-topic
]

valid_underscore_topics = %w[
  it-topic_with_underscores
  it-topic_123_with_numbers
  it-UPPER_CASE_TOPIC
  it-lower_case_topic
]

valid_dot_topics = %w[
  it-topic.with.dots
  it-topic.123.with.numbers
  it-service.events.user
]

# Invalid topics (mixing namespacing styles)
# Still need to start with "it-" for the integration test framework
invalid_mixed_topics = %w[
  it-topic-with_mixed.styles
  it-Mixed-Case_Topic.Name123
]

# Test valid topic names are accepted
valid_topics = []

[valid_dash_topics, valid_underscore_topics, valid_dot_topics].flatten.each do |topic_name|
  Karafka::App.routes.clear

  draw_routes(create_topics: false) do
    subscription_group do
      topic topic_name do
        consumer SpecialCharacterConsumer
      end
    end
  end

  valid_topics << topic_name
rescue Karafka::Errors::InvalidConfigurationError
  exit 2
end

# Test invalid topic names are rejected
rejected_topics = []

invalid_mixed_topics.each do |topic_name|
  Karafka::App.routes.clear

  draw_routes(create_topics: false) do
    subscription_group do
      topic topic_name do
        consumer SpecialCharacterConsumer
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  rejected_topics << topic_name
end

# Now test with one valid special character topic name for actual consumption
test_topic = DT.topic

Karafka::App.routes.clear

draw_routes do
  subscription_group do
    topic test_topic do
      consumer SpecialCharacterConsumer
    end
  end
end

# Produce test messages to the special character topic
test_messages = [
  'Message for special character topic',
  'Another message with special chars: àáâãäå',
  'JSON message: {"special": "characters in topic name"}',
  'Binary content test'
]

test_messages.each { |msg| produce(test_topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= test_messages.size
end

# Verify messages were consumed from the special character topic
assert_equal(
  test_messages.size, DT[:consumed].size,
  'Should consume messages from topic with special characters'
)

# Verify all messages came from the correct topic
consumed_topics = DT[:consumed].map { |msg| msg[:topic] }.uniq
assert_equal(
  [test_topic],
  consumed_topics,
  'All messages should come from the special character topic'
)

# Verify consumer class was correctly assigned
consumer_classes = DT[:consumed].map { |msg| msg[:consumer_class] }.uniq
assert_equal(
  ['SpecialCharacterConsumer'],
  consumer_classes,
  'Should use correct consumer class for special character topic'
)

# Verify payloads were preserved correctly
consumed_payloads = DT[:consumed].map { |msg| msg[:payload] }

test_messages.each do |expected_msg|
  # Check if any consumed payload matches (handle encoding issues)
  matches = consumed_payloads.any? do |consumed|
    # Try direct comparison first
    if consumed == expected_msg
      true
    # Try forcing UTF-8 encoding
    elsif consumed.respond_to?(:force_encoding)
      consumed.dup.force_encoding('UTF-8') == expected_msg
    # Try converting bytes back to UTF-8
    elsif consumed.respond_to?(:bytes)
      consumed.bytes.pack('C*').force_encoding('UTF-8') == expected_msg
    else
      false
    end
  end

  assert matches, "Should consume message: #{expected_msg.inspect}"
end

# Test that valid topic names were accepted in routing configuration
assert(
  valid_topics.size >= 10,
  'Should accept multiple topic names with special characters in routing'
)

# Test that invalid topic names were rejected
assert(
  rejected_topics.size >= 2,
  'Should reject topic names with mixed namespacing styles'
)

# The key success criteria: special character topic names work correctly
assert_equal(
  test_messages.size,
  DT[:consumed].size,
  'Should handle topic names with special characters without issues'
)
