# frozen_string_literal: true

# Karafka should allow reopening the implicit default consumer group
# when using the simple topic style across multiple draw calls

setup_karafka

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)
Consumer3 = Class.new(Karafka::BaseConsumer)

# First draw - use simple topic style (creates implicit default consumer group)
draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer1
  end
end

# Verify implicit consumer group was created
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
# The default group id comes from the config
assert_equal 1, group.topics.size
assert_equal [DT.topics[0]], group.topics.map(&:name)

# Second draw - use simple topic style again (should reopen default group)
draw_routes(create_topics: false) do
  topic DT.topics[1] do
    consumer Consumer2
  end
end

# Verify topics accumulated in the same default group
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
assert_equal 2, group.topics.size
assert_equal [DT.topics[0], DT.topics[1]].sort, group.topics.map(&:name).sort

# Third draw - use simple topic style again
draw_routes(create_topics: false) do
  topic DT.topics[2] do
    consumer Consumer3
  end
end

# Verify all topics accumulated in the same default group
assert_equal 1, Karafka::App.routes.size
group = Karafka::App.routes.first
assert_equal 3, group.topics.size
assert_equal [DT.topics[0], DT.topics[1], DT.topics[2]].sort, group.topics.map(&:name).sort

# Verify each topic has the correct consumer
topic0 = group.topics.to_a.find { |t| t.name == DT.topics[0] }
topic1 = group.topics.to_a.find { |t| t.name == DT.topics[1] }
topic2 = group.topics.to_a.find { |t| t.name == DT.topics[2] }
assert_equal Consumer1, topic0.consumer
assert_equal Consumer2, topic1.consumer
assert_equal Consumer3, topic2.consumer
