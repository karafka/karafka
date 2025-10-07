# frozen_string_literal: true

# Test mixing explicit consumer group definitions with implicit default group usage
# This verifies that 'app' (default group) and named groups can coexist

setup_karafka

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)
Consumer3 = Class.new(Karafka::BaseConsumer)
Consumer4 = Class.new(Karafka::BaseConsumer)

# First draw - use simple topic style (creates implicit 'app' group)
draw_routes(create_topics: false) do
  topic 'implicit_topic1' do
    consumer Consumer1
  end
end

# Second draw - add explicit named consumer group
draw_routes(create_topics: false) do
  consumer_group 'named_group' do
    topic 'explicit_topic1' do
      consumer Consumer2
    end
  end
end

# Third draw - reopen implicit 'app' group
draw_routes(create_topics: false) do
  topic 'implicit_topic2' do
    consumer Consumer3
  end
end

# Fourth draw - reopen explicit named group
draw_routes(create_topics: false) do
  consumer_group 'named_group' do
    topic 'explicit_topic2' do
      consumer Consumer4
    end
  end
end

# Verify we have two consumer groups
assert_equal 2, Karafka::App.routes.size

# Find both groups - one is the default implicit group, one is named
named_group = Karafka::App.routes.find { |cg| cg.name == 'named_group' }
default_group = Karafka::App.routes.find { |cg| cg.name != 'named_group' }

# Verify default implicit group exists
raise 'default implicit group should exist' if default_group.nil?

assert_equal 2, default_group.topics.size
assert_equal %w[implicit_topic1 implicit_topic2], default_group.topics.map(&:name).sort

# Verify named group exists
raise 'named_group should exist' if named_group.nil?

assert_equal 2, named_group.topics.size
assert_equal %w[explicit_topic1 explicit_topic2], named_group.topics.map(&:name).sort

# Verify consumers
assert_equal Consumer1, default_group.topics.to_a.find { |t| t.name == 'implicit_topic1' }.consumer
assert_equal Consumer3, default_group.topics.to_a.find { |t| t.name == 'implicit_topic2' }.consumer
assert_equal Consumer2, named_group.topics.to_a.find { |t| t.name == 'explicit_topic1' }.consumer
assert_equal Consumer4, named_group.topics.to_a.find { |t| t.name == 'explicit_topic2' }.consumer
