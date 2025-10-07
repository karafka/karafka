# frozen_string_literal: true

# Karafka should allow reopening consumer groups across multiple draw calls
# This enables splitting routing configuration across multiple files

setup_karafka

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)

# First draw - define consumer group with one topic
draw_routes(create_topics: false) do
  consumer_group 'mygroup' do
    topic 'topic1' do
      consumer Consumer1
    end
  end
end

# Second draw - reopen the same consumer group and add another topic
draw_routes(create_topics: false) do
  consumer_group 'mygroup' do
    topic 'topic2' do
      consumer Consumer2
    end
  end
end

# Verify the consumer group exists and has both topics
consumer_group = Karafka::App.routes.find { |cg| cg.name == 'mygroup' }

# Basic assertions
raise 'Consumer group should exist' unless consumer_group
raise 'Wrong consumer group name' unless consumer_group.name == 'mygroup'
raise "Expected 2 topics, got #{consumer_group.topics.size}" unless consumer_group.topics.size == 2

topic_names = consumer_group.topics.map(&:name).sort
expected_topics = %w[topic1 topic2]

unless topic_names == expected_topics
  raise "Expected #{expected_topics.inspect}, got #{topic_names.inspect}"
end

# Verify each topic has the correct consumer
topic1 = consumer_group.topics.to_a.find { |t| t.name == 'topic1' }
topic2 = consumer_group.topics.to_a.find { |t| t.name == 'topic2' }
raise 'topic1 should have Consumer1' unless topic1.consumer == Consumer1
raise 'topic2 should have Consumer2' unless topic2.consumer == Consumer2
