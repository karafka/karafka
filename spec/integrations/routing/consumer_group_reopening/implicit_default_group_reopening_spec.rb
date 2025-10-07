# frozen_string_literal: true

# Karafka should allow reopening the implicit default consumer group (named 'app')
# when using the simple topic style across multiple draw calls

setup_karafka

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)
Consumer3 = Class.new(Karafka::BaseConsumer)

# First draw - use simple topic style (creates implicit 'app' consumer group)
draw_routes(create_topics: false) do
  topic 'topic1' do
    consumer Consumer1
  end
end

# Verify implicit consumer group was created
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
# The default group id comes from the config
assert_equal 1, group.topics.size
assert_equal ['topic1'], group.topics.map(&:name)

# Second draw - use simple topic style again (should reopen 'app' group)
draw_routes(create_topics: false) do
  topic 'topic2' do
    consumer Consumer2
  end
end

# Verify topics accumulated in the same default group
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
assert_equal 2, group.topics.size
assert_equal %w[topic1 topic2], group.topics.map(&:name).sort

# Third draw - use simple topic style again
draw_routes(create_topics: false) do
  topic 'topic3' do
    consumer Consumer3
  end
end

# Verify all topics accumulated in the same default group
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
assert_equal 3, group.topics.size
assert_equal %w[topic1 topic2 topic3], group.topics.map(&:name).sort

# Verify each topic has the correct consumer
topic1 = group.topics.to_a.find { |t| t.name == 'topic1' }
topic2 = group.topics.to_a.find { |t| t.name == 'topic2' }
topic3 = group.topics.to_a.find { |t| t.name == 'topic3' }
assert_equal Consumer1, topic1.consumer
assert_equal Consumer2, topic2.consumer
assert_equal Consumer3, topic3.consumer
