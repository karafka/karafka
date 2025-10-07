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

# Draw 1: Create group_a with one topic
draw_routes(create_topics: false) do
  consumer_group 'group_a' do
    topic 'a1' do
      consumer Consumer1
    end
  end
end

# Draw 2: Create group_b with one topic
draw_routes(create_topics: false) do
  consumer_group 'group_b' do
    topic 'b1' do
      consumer Consumer2
    end
  end
end

# Draw 3: Add to implicit app group
draw_routes(create_topics: false) do
  topic 'implicit1' do
    consumer Consumer3
  end
end

# Draw 4: Reopen group_a and add another topic
draw_routes(create_topics: false) do
  consumer_group 'group_a' do
    topic 'a2' do
      consumer Consumer4
    end
  end
end

# Draw 5: Reopen implicit app group
draw_routes(create_topics: false) do
  topic 'implicit2' do
    consumer Consumer5
  end
end

# Draw 6: Reopen group_b and add another topic
draw_routes(create_topics: false) do
  consumer_group 'group_b' do
    topic 'b2' do
      consumer Consumer6
    end
  end
end

# Verify we have three consumer groups total
assert_equal 3, Karafka::App.routes.size

# Find all groups
group_a = Karafka::App.routes.find { |cg| cg.name == 'group_a' }
group_b = Karafka::App.routes.find { |cg| cg.name == 'group_b' }
default_group = Karafka::App.routes.find { |cg| cg.name != 'group_a' && cg.name != 'group_b' }

# Verify group_a has both topics
raise 'group_a should exist' if group_a.nil?

assert_equal 2, group_a.topics.size
assert_equal %w[a1 a2], group_a.topics.map(&:name).sort

# Verify group_b has both topics
raise 'group_b should exist' if group_b.nil?

assert_equal 2, group_b.topics.size
assert_equal %w[b1 b2], group_b.topics.map(&:name).sort

# Verify default implicit group has both implicit topics
raise 'default implicit group should exist' if default_group.nil?

assert_equal 2, default_group.topics.size
assert_equal %w[implicit1 implicit2], default_group.topics.map(&:name).sort

# Verify all consumers are correctly assigned
assert_equal Consumer1, group_a.topics.to_a.find { |t| t.name == 'a1' }.consumer
assert_equal Consumer4, group_a.topics.to_a.find { |t| t.name == 'a2' }.consumer
assert_equal Consumer2, group_b.topics.to_a.find { |t| t.name == 'b1' }.consumer
assert_equal Consumer6, group_b.topics.to_a.find { |t| t.name == 'b2' }.consumer
assert_equal Consumer3, default_group.topics.to_a.find { |t| t.name == 'implicit1' }.consumer
assert_equal Consumer5, default_group.topics.to_a.find { |t| t.name == 'implicit2' }.consumer
