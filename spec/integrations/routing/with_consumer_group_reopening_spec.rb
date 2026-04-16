# frozen_string_literal: true

# Karafka should allow reopening consumer groups across multiple draw calls
# This enables splitting routing configuration across multiple files

setup_karafka

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)

# First draw - define consumer group with one topic
draw_routes(create_topics: false) do
  consumer_group DT.groups[0] do
    topic DT.topics[0] do
      consumer Consumer1
    end
  end
end

# Second draw - reopen the same consumer group and add another topic
draw_routes(create_topics: false) do
  consumer_group DT.groups[0] do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

# Verify the consumer group exists and has both topics
group = Karafka::App.routes.find { |cg| cg.name == DT.groups[0] }

# Basic assertions
raise "Consumer group should exist" unless group
raise "Wrong consumer group name" unless group.name == DT.groups[0]
raise "Expected 2 topics, got #{group.topics.size}" unless group.topics.size == 2

topic_names = group.topics.map(&:name).sort
expected_topics = [DT.topics[0], DT.topics[1]].sort

unless topic_names == expected_topics
  raise "Expected #{expected_topics.inspect}, got #{topic_names.inspect}"
end

# Verify each topic has the correct consumer
topic0 = group.topics.to_a.find { |t| t.name == DT.topics[0] }
topic1 = group.topics.to_a.find { |t| t.name == DT.topics[1] }
raise "topic0 should have Consumer1" unless topic0.consumer == Consumer1
raise "topic1 should have Consumer2" unless topic1.consumer == Consumer2
