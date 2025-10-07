# frozen_string_literal: true

# Test what happens when the same topic name is defined twice when reopening a consumer group
# Expected: Karafka should raise InvalidConfigurationError because duplicate topic names
# within a consumer group are not allowed

setup_karafka

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)

# First draw - define consumer group with a topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer1
      initial_offset 'earliest'
    end
  end
end

# Verify first draw
group = Karafka::App.routes.first
assert_equal 1, group.topics.size
topic_first = group.topics.to_a.first
assert_equal DT.topics[0], topic_first.name
assert_equal Consumer1, topic_first.consumer
assert_equal 'earliest', topic_first.initial_offset

# Second draw - try to define the same topic again with different settings
# This should raise an error because duplicate topic names are not allowed
error_raised = false
error_message = nil

begin
  draw_routes(create_topics: false) do
    consumer_group DT.consumer_groups[0] do
      topic DT.topics[0] do
        consumer Consumer2
        initial_offset 'latest'
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  error_raised = true
  error_message = e.message
end

# Verify that duplicate topic definition was rejected
raise 'Should raise InvalidConfigurationError for duplicate topic' unless error_raised

unless error_message.include?('topic names within a single consumer group must be unique')
  raise "Error message should mention unique topic names, got: #{error_message}"
end

# Check the state after validation failure
# Note: The duplicate topic is actually added before validation runs,
# so after a validation failure, the routes may have both topics
group = Karafka::App.routes.first

# The behavior is: topic gets added, then validation catches the duplicate
# So we should have 2 topics after the failed draw
expected_message = 'Should have two topics after failed validation (added before validation)'
assert_equal 2, group.topics.size, expected_message

# Both topics exist but the configuration is invalid
topics = group.topics.to_a
raise 'Should have duplicate topics' unless topics.any? { |t| t.name == DT.topics[0] }
