# frozen_string_literal: true

# Test mixing explicit consumer group definitions with implicit default group usage
# This verifies that default group and named groups can coexist

setup_karafka

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)
Consumer3 = Class.new(Karafka::BaseConsumer)
Consumer4 = Class.new(Karafka::BaseConsumer)

# First draw - use simple topic style (creates implicit default group)
draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer1
  end
end

# Second draw - add explicit named consumer group
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[1] do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

# Third draw - reopen implicit default group
draw_routes(create_topics: false) do
  topic DT.topics[2] do
    consumer Consumer3
  end
end

# Fourth draw - reopen explicit named group
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[1] do
    topic DT.topics[3] do
      consumer Consumer4
    end
  end
end

# Verify we have two consumer groups
assert_equal 2, Karafka::App.routes.size

# Find both groups - one is the default implicit group, one is named
named_group = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[1] }
default_group = Karafka::App.routes.find { |cg| cg.name != DT.consumer_groups[1] }

# Verify default implicit group exists
raise 'default implicit group should exist' if default_group.nil?

assert_equal 2, default_group.topics.size
assert_equal [DT.topics[0], DT.topics[2]].sort, default_group.topics.map(&:name).sort

# Verify named group exists
raise 'named_group should exist' if named_group.nil?

assert_equal 2, named_group.topics.size
assert_equal [DT.topics[1], DT.topics[3]].sort, named_group.topics.map(&:name).sort

# Verify consumers
assert_equal Consumer1, default_group.topics.to_a.find { |t| t.name == DT.topics[0] }.consumer
assert_equal Consumer3, default_group.topics.to_a.find { |t| t.name == DT.topics[2] }.consumer
assert_equal Consumer2, named_group.topics.to_a.find { |t| t.name == DT.topics[1] }.consumer
assert_equal Consumer4, named_group.topics.to_a.find { |t| t.name == DT.topics[3] }.consumer
