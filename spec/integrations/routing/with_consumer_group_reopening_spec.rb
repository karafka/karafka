# frozen_string_literal: true

# Karafka should allow reopening consumer groups across multiple draw calls
# This enables splitting routing configuration across multiple files

setup_karafka

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)

# First draw - define consumer group with one topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer1
    end
  end
end

# Second draw - reopen the same consumer group and add another topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

# Verify the consumer group exists and has both topics
consumer_group = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[0] }

# Basic assertions
raise "Consumer group should exist" unless consumer_group
raise "Wrong consumer group name" unless consumer_group.name == DT.consumer_groups[0]
raise "Expected 2 topics, got #{consumer_group.topics.size}" unless consumer_group.topics.size == 2

topic_names = consumer_group.topics.map(&:name).sort
expected_topics = [DT.topics[0], DT.topics[1]].sort

unless topic_names == expected_topics
  raise "Expected #{expected_topics.inspect}, got #{topic_names.inspect}"
end

# Verify each topic has the correct consumer
topic0 = consumer_group.topics.to_a.find { |t| t.name == DT.topics[0] }
topic1 = consumer_group.topics.to_a.find { |t| t.name == DT.topics[1] }
raise "topic0 should have Consumer1" unless topic0.consumer == Consumer1
raise "topic1 should have Consumer2" unless topic1.consumer == Consumer2
