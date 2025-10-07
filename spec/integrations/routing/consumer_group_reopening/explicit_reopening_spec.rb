# frozen_string_literal: true

# Karafka should allow reopening explicitly named consumer groups across multiple draw calls
# This test verifies that topics accumulate correctly when the same consumer group is defined
# multiple times

setup_karafka

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)
Consumer3 = Class.new(Karafka::BaseConsumer)

# First draw - define consumer group with one topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer1
    end
  end
end

# Verify first draw created the group
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
assert_equal DT.consumer_groups[0], group.name
assert_equal 1, group.topics.size
assert_equal [DT.topics[0]], group.topics.map(&:name)

# Second draw - reopen same consumer group and add another topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

# Verify topics accumulated
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
assert_equal DT.consumer_groups[0], group.name
assert_equal 2, group.topics.size
assert_equal [DT.topics[0], DT.topics[1]].sort, group.topics.map(&:name).sort

# Third draw - reopen again and add another topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[2] do
      consumer Consumer3
    end
  end
end

# Verify all topics accumulated
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
assert_equal DT.consumer_groups[0], group.name
assert_equal 3, group.topics.size
assert_equal [DT.topics[0], DT.topics[1], DT.topics[2]].sort, group.topics.map(&:name).sort

# Verify each topic has the correct consumer
topic0 = group.topics.to_a.find { |t| t.name == DT.topics[0] }
topic1 = group.topics.to_a.find { |t| t.name == DT.topics[1] }
topic2 = group.topics.to_a.find { |t| t.name == DT.topics[2] }
assert_equal Consumer1, topic0.consumer
assert_equal Consumer2, topic1.consumer
assert_equal Consumer3, topic2.consumer
