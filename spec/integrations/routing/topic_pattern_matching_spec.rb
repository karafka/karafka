# frozen_string_literal: true

# Karafka should handle topic routing patterns and naming edge cases

setup_karafka

class PatternMatchConsumer < Karafka::BaseConsumer
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

# Test topic naming patterns that might cause routing conflicts or edge cases
# Note: All integration test topics must start with "it-"
test_topics = [
  DT.topic,
  "#{DT.topic}_suffix",
  "#{DT.topic}_another_suffix",
  "#{DT.topic}_with_prefix",
  "#{DT.topic}_middle_suffix"
]

# Set up routing for different topic patterns
Karafka::App.routes.clear

draw_routes do
  subscription_group "pattern_group" do
    test_topics.each do |topic_name|
      topic topic_name do
        consumer PatternMatchConsumer
      end
    end
  end
end

# Verify all topics were registered in routing
registered_topics = []
Karafka::App.routes.each do |consumer_group|
  consumer_group.topics.each do |topic|
    registered_topics << topic.name
  end
end

test_topics.each do |expected_topic|
  assert(
    registered_topics.include?(expected_topic),
    "Should register topic pattern: #{expected_topic}"
  )
end

# Test producing to different pattern-based topics
test_messages = test_topics.map.with_index do |topic, index|
  {
    topic: topic,
    message: "Pattern message #{index + 1} for topic: #{topic}"
  }
end

test_messages.each do |msg_data|
  produce(msg_data[:topic], msg_data[:message])
end

start_karafka_and_wait_until do
  DT[:consumed].size >= test_messages.size
end

# Verify all pattern topics received messages correctly
assert_equal(
  test_messages.size, DT[:consumed].size,
  "Should consume messages from all pattern-based topics"
)

# Verify each topic received exactly one message
consumed_by_topic = DT[:consumed].group_by { |msg| msg[:topic] }

test_topics.each do |topic|
  topic_messages = consumed_by_topic[topic] || []
  assert_equal(
    1,
    topic_messages.size,
    "Topic #{topic} should receive exactly one message"
  )
end

# Test that similar topic names don't interfere with each other
topic_message_pairs = test_messages.map do |msg_data|
  consumed_msg = DT[:consumed].find { |c| c[:topic] == msg_data[:topic] }
  {
    expected: msg_data[:message],
    consumed: consumed_msg&.dig(:payload)
  }
end

topic_message_pairs.each do |pair|
  assert_equal(
    pair[:expected], pair[:consumed],
    "Message content should match for topic pattern"
  )
end

# The key success criteria: pattern-based topic handling works correctly
total_consumed = DT[:consumed].size
assert_equal(
  test_messages.size, total_consumed,
  "Should handle topic pattern matching without issues"
)
