# frozen_string_literal: true

# This spec tests the behavior of subscription groups, member IDs, and positions
# when routes are redrawn multiple times in various scenarios:
# - Reopening consumer groups and adding topics
# - Adding new consumer groups
# - Empty draws (no-op)
# - Mixed scenarios with static group membership

setup_karafka do |config|
  config.kafka[:"group.instance.id"] = "test-instance"
end

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)
Consumer3 = Class.new(Karafka::BaseConsumer)
Consumer4 = Class.new(Karafka::BaseConsumer)

# Initial draw with one consumer group and one topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer1
    end
  end
end

cg0 = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[0] }

assert_equal 1, cg0.topics.size
assert_equal 1, cg0.subscription_groups.size

sg0 = cg0.subscription_groups.first
original_sg_id = sg0.id
original_position = sg0.position
original_instance_id = sg0.kafka[:"group.instance.id"]

assert_equal 0, original_position

# Empty redraw - should not change anything
draw_routes(create_topics: false) do
  # Empty
end

assert_equal original_sg_id, cg0.subscription_groups.first.id
assert_equal original_position, cg0.subscription_groups.first.position
assert_equal original_instance_id, cg0.subscription_groups.first.kafka[:"group.instance.id"]

# Reopen consumer group and add a topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

assert_equal 2, cg0.topics.size
assert_equal 1, cg0.subscription_groups.size
assert_equal 0, cg0.subscription_groups.first.position
assert_equal original_instance_id, cg0.subscription_groups.first.kafka[:"group.instance.id"]

# Add a second consumer group
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[1] do
    topic DT.topics[2] do
      consumer Consumer3
    end
  end
end

cg1 = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[1] }

assert_equal 2, Karafka::App.consumer_groups.size
assert_equal 2, cg0.topics.size
assert_equal 1, cg1.topics.size
assert_equal 0, cg0.subscription_groups.first.position
assert_equal 1, cg1.subscription_groups.first.position

# Reopen both consumer groups and add topics
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[3] do
      consumer Consumer4
    end
  end

  consumer_group DT.consumer_groups[1] do
    topic DT.topics[4] do
      consumer Consumer4
    end
  end
end

assert_equal 3, cg0.topics.size
assert_equal 2, cg1.topics.size
assert_equal 0, cg0.subscription_groups.first.position
assert_equal 1, cg1.subscription_groups.first.position

# Multiple consecutive empty draws
3.times do
  draw_routes(create_topics: false) do
    # Empty
  end
end

assert_equal 3, cg0.topics.size
assert_equal 0, cg0.subscription_groups.first.position

# Add third consumer group after many operations
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[2] do
    topic DT.topics[5] do
      consumer Consumer1
    end
  end
end

cg2 = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[2] }

assert_equal 3, Karafka::App.consumer_groups.size
assert_equal 2, cg2.subscription_groups.first.position

# Verify all positions are unique and sequential
all_positions = Karafka::App.consumer_groups.flat_map do |cg|
  cg.subscription_groups.map(&:position)
end.sort

assert_equal [0, 1, 2], all_positions

# Verify all instance IDs are unique
all_instance_ids = Karafka::App.consumer_groups.flat_map do |cg|
  cg.subscription_groups.map { |sg| sg.kafka[:"group.instance.id"] }
end

assert_equal all_instance_ids.size, all_instance_ids.uniq.size
