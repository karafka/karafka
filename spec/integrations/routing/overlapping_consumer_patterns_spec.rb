# frozen_string_literal: true

# Karafka should handle complex consumer patterns and prevent conflicts

setup_karafka

class PatternConsumerA < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed_a] << {
        topic: message.metadata.topic,
        partition: message.metadata.partition,
        payload: message.raw_payload,
        consumer_class: self.class.name
      }
    end
  end
end

class PatternConsumerB < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed_b] << {
        topic: message.metadata.topic,
        partition: message.metadata.partition,
        payload: message.raw_payload,
        consumer_class: self.class.name
      }
    end
  end
end

class PatternConsumerC < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed_c] << {
        topic: message.metadata.topic,
        partition: message.metadata.partition,
        payload: message.raw_payload,
        consumer_class: self.class.name
      }
    end
  end
end

# Test multiple topics in same subscription group (allowed)
Karafka::App.routes.clear

draw_routes do
  subscription_group 'multi_topic_group' do
    topic DT.topic do
      consumer PatternConsumerA
    end

    topic "#{DT.topic}_secondary" do
      consumer PatternConsumerB
    end

    topic "#{DT.topic}_tertiary" do
      consumer PatternConsumerC
    end
  end
end

# Test consumer patterns - produce messages to different topics
test_messages = [
  { topic: DT.topic, message: 'Message for primary topic' },
  { topic: "#{DT.topic}_secondary", message: 'Message for secondary topic' },
  { topic: "#{DT.topic}_tertiary", message: 'Message for tertiary topic' }
]

test_messages.each do |msg_info|
  produce(msg_info[:topic], msg_info[:message])
end

start_karafka_and_wait_until do
  (DT[:consumed_a].size + DT[:consumed_b].size + DT[:consumed_c].size) >= test_messages.size
end

# Verify messages went to correct consumers
assert_equal 1, DT[:consumed_a].size, 'Consumer A should receive 1 message'
assert_equal 1, DT[:consumed_b].size, 'Consumer B should receive 1 message'
assert_equal 1, DT[:consumed_c].size, 'Consumer C should receive 1 message'

# Verify each consumer received the correct topic's message
assert_equal DT.topic, DT[:consumed_a].first[:topic],
             'Consumer A should receive message from primary topic'
assert_equal "#{DT.topic}_secondary", DT[:consumed_b].first[:topic],
             'Consumer B should receive message from secondary topic'
assert_equal "#{DT.topic}_tertiary", DT[:consumed_c].first[:topic],
             'Consumer C should receive message from tertiary topic'

# Verify correct consumer class assignment
assert_equal 'PatternConsumerA', DT[:consumed_a].first[:consumer_class],
             'Should use PatternConsumerA for primary topic'
assert_equal 'PatternConsumerB', DT[:consumed_b].first[:consumer_class],
             'Should use PatternConsumerB for secondary topic'
assert_equal 'PatternConsumerC', DT[:consumed_c].first[:consumer_class],
             'Should use PatternConsumerC for tertiary topic'

# Test that attempting to assign same topic to multiple consumers fails
Karafka::App.routes.clear
duplicate_assignment_failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group 'conflicting_group' do
      topic :same_topic_name do
        consumer PatternConsumerA
      end

      # This should fail - same topic in same subscription group
      topic :same_topic_name do
        consumer PatternConsumerB
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  duplicate_assignment_failed = true
end

# Test consumer assignment patterns across multiple subscription groups
Karafka::App.routes.clear
multiple_groups_failed = false

begin
  draw_routes(create_topics: false) do
    subscription_group 'group_1' do
      topic :shared_topic_name do
        consumer PatternConsumerA
      end
    end

    subscription_group 'group_2' do
      # This should fail - same topic name in different subscription groups
      topic :shared_topic_name do
        consumer PatternConsumerB
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  multiple_groups_failed = true
end

# Test overlapping configuration validation
assert(
  duplicate_assignment_failed,
  'Should prevent duplicate topic assignment within same subscription group'
)

assert(
  multiple_groups_failed,
  'Should prevent same topic name across different subscription groups'
)

# Test successful multi-consumer pattern within single subscription group
total_consumed = DT[:consumed_a].size + DT[:consumed_b].size + DT[:consumed_c].size
assert_equal(
  test_messages.size, total_consumed,
  'Should handle multiple consumers in same subscription group correctly'
)

# Verify no message duplication occurred
all_consumed_messages = (DT[:consumed_a] + DT[:consumed_b] + DT[:consumed_c])
topics_consumed = all_consumed_messages.map { |msg| msg[:topic] }
expected_topics = test_messages.map { |msg| msg[:topic] }

expected_topics.each do |expected_topic|
  topic_count = topics_consumed.count(expected_topic)
  assert_equal 1, topic_count, "Should consume exactly one message from #{expected_topic}"
end
