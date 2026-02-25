# frozen_string_literal: true

# Karafka should handle dynamic routing patterns and topic configuration edge cases

setup_karafka

class DynamicConsumer < Karafka::BaseConsumer
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

# Test building routes dynamically
topics_to_create = [
  "#{DT.topic}_dynamic_1",
  "#{DT.topic}_dynamic_2",
  "#{DT.topic}_dynamic_3"
]

# Build routes dynamically
Karafka::App.routes.clear

draw_routes do
  subscription_group "dynamic_group" do
    topics_to_create.each do |topic_name|
      topic topic_name do
        consumer DynamicConsumer
      end
    end
  end
end

# Verify routes were created correctly
created_topics = []
Karafka::App.routes.each do |consumer_group|
  consumer_group.topics.each do |topic|
    created_topics << topic.name
  end
end

topics_to_create.each do |expected_topic|
  assert created_topics.include?(expected_topic)
end

# Test producing to dynamically created topics
test_data = topics_to_create.map.with_index do |topic, index|
  {
    topic: topic,
    message: "Dynamic message #{index + 1} for #{topic}"
  }
end

test_data.each do |data|
  produce(data[:topic], data[:message])
end

start_karafka_and_wait_until do
  DT[:consumed].size >= test_data.size
end

# Verify all dynamic topics received messages
consumed_topics = DT[:consumed].map { |msg| msg[:topic] }.uniq.sort
expected_topics = topics_to_create.sort

assert_equal expected_topics, consumed_topics

# Verify correct number of messages
assert_equal test_data.size, DT[:consumed].size

# Verify each topic got exactly one message
topics_to_create.each do |topic|
  topic_messages = DT[:consumed].select { |msg| msg[:topic] == topic }
  assert_equal 1, topic_messages.size
end

# Test routing configuration modification at runtime
# Clear and rebuild with different configuration
Karafka::App.routes.clear

additional_topics = [
  "#{DT.topic}_runtime_1",
  "#{DT.topic}_runtime_2"
]

draw_routes(create_topics: false) do
  subscription_group "runtime_group" do
    additional_topics.each do |topic_name|
      topic topic_name do
        consumer DynamicConsumer
      end
    end
  end
end

# Verify new configuration replaced the old one
new_topics = []
Karafka::App.routes.each do |consumer_group|
  consumer_group.topics.each do |topic|
    new_topics << topic.name
  end
end
new_topics_count = new_topics.size

# Should have different topics now
assert_equal additional_topics.size, new_topics_count

additional_topics.each do |expected_topic|
  assert new_topics.include?(expected_topic)
end

# Test conditional topic creation based on configuration
Karafka::App.routes.clear

conditional_topics = []
feature_flags = {
  enable_feature_a: true,
  enable_feature_b: false,
  enable_feature_c: true
}

draw_routes(create_topics: false) do
  subscription_group "conditional_group" do
    if feature_flags[:enable_feature_a]
      topic "#{DT.topic}_feature_a" do
        consumer DynamicConsumer
      end
      conditional_topics << "#{DT.topic}_feature_a"
    end

    if feature_flags[:enable_feature_b]
      topic "#{DT.topic}_feature_b" do
        consumer DynamicConsumer
      end
      conditional_topics << "#{DT.topic}_feature_b"
    end

    if feature_flags[:enable_feature_c]
      topic "#{DT.topic}_feature_c" do
        consumer DynamicConsumer
      end
      conditional_topics << "#{DT.topic}_feature_c"
    end
  end
end

# Verify conditional topics were created correctly
conditional_route_topics = []
Karafka::App.routes.each do |consumer_group|
  consumer_group.topics.each do |topic|
    conditional_route_topics << topic.name
  end
end

assert(
  conditional_route_topics.include?("#{DT.topic}_feature_a"),
  "Should include feature_a topic when enabled"
)

assert(
  !conditional_route_topics.include?("#{DT.topic}_feature_b"),
  "Should not include feature_b topic when disabled"
)

assert(
  conditional_route_topics.include?("#{DT.topic}_feature_c"),
  "Should include feature_c topic when enabled"
)

assert_equal(
  2,
  conditional_route_topics.size,
  "Should create exactly 2 topics based on feature flags"
)

# The key success criteria: dynamic routing works correctly
assert_equal(
  test_data.size, DT[:consumed].size,
  "Should handle dynamic topic creation and message consumption"
)
