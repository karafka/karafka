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
  consumer_group 'explicit_group' do
    topic 'topic1' do
      consumer Consumer1
    end
  end
end

# Verify first draw created the group
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
assert_equal 'explicit_group', group.name
assert_equal 1, group.topics.size
assert_equal ['topic1'], group.topics.map(&:name)

# Second draw - reopen same consumer group and add another topic
draw_routes(create_topics: false) do
  consumer_group 'explicit_group' do
    topic 'topic2' do
      consumer Consumer2
    end
  end
end

# Verify topics accumulated
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
assert_equal 'explicit_group', group.name
assert_equal 2, group.topics.size
assert_equal %w[topic1 topic2], group.topics.map(&:name).sort

# Third draw - reopen again and add another topic
draw_routes(create_topics: false) do
  consumer_group 'explicit_group' do
    topic 'topic3' do
      consumer Consumer3
    end
  end
end

# Verify all topics accumulated
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
assert_equal 'explicit_group', group.name
assert_equal 3, group.topics.size
assert_equal %w[topic1 topic2 topic3], group.topics.map(&:name).sort

# Verify each topic has the correct consumer
topic1 = group.topics.to_a.find { |t| t.name == 'topic1' }
topic2 = group.topics.to_a.find { |t| t.name == 'topic2' }
topic3 = group.topics.to_a.find { |t| t.name == 'topic3' }
assert_equal Consumer1, topic1.consumer
assert_equal Consumer2, topic2.consumer
assert_equal Consumer3, topic3.consumer
