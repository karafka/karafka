# frozen_string_literal: true

# Comprehensive test covering multiple consumer group reopening scenarios:
# - Multiple named consumer groups
# - Implicit default group
# - Reopening multiple times
# - All in a single test to verify complex interactions

setup_karafka

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)
Consumer3 = Class.new(Karafka::BaseConsumer)
Consumer4 = Class.new(Karafka::BaseConsumer)
Consumer5 = Class.new(Karafka::BaseConsumer)
Consumer6 = Class.new(Karafka::BaseConsumer)

# Draw 1: Create first named group with one topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[1] do
    topic DT.topics[0] do
      consumer Consumer1
    end
  end
end

# Draw 2: Create second named group with one topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[2] do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

# Draw 3: Add to implicit default group (uses DT.consumer_groups[0] from config)
draw_routes(create_topics: false) do
  topic DT.topics[2] do
    consumer Consumer3
  end
end

# Draw 4: Reopen first named group and add another topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[1] do
    topic DT.topics[3] do
      consumer Consumer4
    end
  end
end

# Draw 5: Reopen implicit default group
draw_routes(create_topics: false) do
  topic DT.topics[4] do
    consumer Consumer5
  end
end

# Draw 6: Reopen second named group and add another topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[2] do
    topic DT.topics[5] do
      consumer Consumer6
    end
  end
end

# Verify we have three consumer groups total
assert_equal 3, Karafka::App.routes.size

# Find all groups
group_a = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[1] }
group_b = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[2] }
default_group = Karafka::App.routes.find do |cg|
  cg.name != DT.consumer_groups[1] && cg.name != DT.consumer_groups[2]
end

# Verify first named group has both topics
raise "first named group should exist" if group_a.nil?

assert_equal 2, group_a.topics.size
assert_equal [DT.topics[0], DT.topics[3]].sort, group_a.topics.map(&:name).sort

# Verify second named group has both topics
raise "second named group should exist" if group_b.nil?

assert_equal 2, group_b.topics.size
assert_equal [DT.topics[1], DT.topics[5]].sort, group_b.topics.map(&:name).sort

# Verify default implicit group has both implicit topics
raise "default implicit group should exist" if default_group.nil?

assert_equal 2, default_group.topics.size
assert_equal [DT.topics[2], DT.topics[4]].sort, default_group.topics.map(&:name).sort

# Verify all consumers are correctly assigned
assert_equal Consumer1, group_a.topics.to_a.find { |t| t.name == DT.topics[0] }.consumer
assert_equal Consumer4, group_a.topics.to_a.find { |t| t.name == DT.topics[3] }.consumer
assert_equal Consumer2, group_b.topics.to_a.find { |t| t.name == DT.topics[1] }.consumer
assert_equal Consumer6, group_b.topics.to_a.find { |t| t.name == DT.topics[5] }.consumer
assert_equal Consumer3, default_group.topics.to_a.find { |t| t.name == DT.topics[2] }.consumer
assert_equal Consumer5, default_group.topics.to_a.find { |t| t.name == DT.topics[4] }.consumer
