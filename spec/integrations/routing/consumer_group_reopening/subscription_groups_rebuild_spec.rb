# frozen_string_literal: true

# Karafka should rebuild subscription groups when consumer groups are reopened
# This ensures that topics added in subsequent draw calls are included in subscription groups
# Ref: https://github.com/karafka/karafka/issues/2915

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

# Get reference to consumer group after first draw
group = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[0] }

# Verify initial state
assert_equal 1, group.topics.size
assert_equal 1, group.subscription_groups.size
assert_equal [DT.topics[0]], group.subscription_groups.first.topics.map(&:name)

# Second draw - reopen consumer group and add another topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

# Verify subscription groups were rebuilt to include new topic
assert_equal 2, group.topics.size
assert_equal 1, group.subscription_groups.size
expected = [DT.topics[0], DT.topics[1]].sort
actual = group.subscription_groups.first.topics.map(&:name).sort
assert_equal expected, actual

# Third draw - add another topic to the same group
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[2] do
      consumer Consumer3
    end
  end
end

# Verify subscription groups include all three topics
assert_equal 3, group.topics.size
assert_equal 1, group.subscription_groups.size
assert_equal(
  [DT.topics[0], DT.topics[1], DT.topics[2]].sort,
  group.subscription_groups.first.topics.map(&:name).sort
)
