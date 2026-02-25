# frozen_string_literal: true

# This spec tests the behavior when topics within the same consumer group
# have different settings and end up in different subscription groups.
# It verifies that positions remain stable across redraws even with
# multiple subscription groups per consumer group.

setup_karafka do |config|
  config.kafka[:"group.instance.id"] = "multi-sg-test"
end

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)

# Create consumer group with topic using default settings
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer1
    end
  end
end

cg0 = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[0] }

assert_equal 1, cg0.subscription_groups.size

sg_default = cg0.subscription_groups.first
sg_default_position = sg_default.position
sg_default_instance_id = sg_default.kafka[:"group.instance.id"]

assert_equal 0, sg_default_position

# Add topic with DIFFERENT max_messages (creates new subscription group)
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[1] do
      consumer Consumer2
      max_messages 500
    end
  end
end

assert_equal 2, cg0.subscription_groups.size

sg_default = cg0.subscription_groups.find { |sg| sg.topics.map(&:name).include?(DT.topics[0]) }
sg_custom = cg0.subscription_groups.find { |sg| sg.topics.map(&:name).include?(DT.topics[1]) }

assert_equal 0, sg_default.position
assert_equal 1, sg_custom.position
assert_equal sg_default_instance_id, sg_default.kafka[:"group.instance.id"]

sg_custom_position = sg_custom.position
sg_custom_instance_id = sg_custom.kafka[:"group.instance.id"]

# Add another topic to the default settings subscription group
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[2] do
      consumer Consumer1
    end
  end
end

assert_equal 2, cg0.subscription_groups.size

sg_default = cg0.subscription_groups.find { |sg| sg.topics.map(&:name).include?(DT.topics[0]) }
sg_custom = cg0.subscription_groups.find { |sg| sg.topics.map(&:name).include?(DT.topics[1]) }

assert_equal 2, sg_default.topics.size
assert_equal [DT.topics[0], DT.topics[2]].sort, sg_default.topics.map(&:name).sort
assert_equal sg_default_position, sg_default.position
assert_equal sg_custom_position, sg_custom.position
assert_equal sg_custom_instance_id, sg_custom.kafka[:"group.instance.id"]

# Add another topic to the custom settings subscription group
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[3] do
      consumer Consumer2
      max_messages 500
    end
  end
end

assert_equal 2, cg0.subscription_groups.size

sg_custom = cg0.subscription_groups.find { |sg| sg.topics.map(&:name).include?(DT.topics[1]) }

assert_equal 2, sg_custom.topics.size
assert_equal [DT.topics[1], DT.topics[3]].sort, sg_custom.topics.map(&:name).sort
assert_equal sg_custom_position, sg_custom.position

# Add a second consumer group with its own subscription groups
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[1] do
    topic DT.topics[4] do
      consumer Consumer1
    end

    topic DT.topics[5] do
      consumer Consumer2
      max_messages 250
    end
  end
end

cg1 = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[1] }

assert_equal 2, Karafka::App.consumer_groups.size
assert_equal 2, cg0.subscription_groups.size
assert_equal 2, cg1.subscription_groups.size

# Verify positions across all subscription groups
cg0_positions = cg0.subscription_groups.map(&:position).sort
cg1_positions = cg1.subscription_groups.map(&:position).sort

assert_equal [0, 1], cg0_positions
assert_equal [2, 3], cg1_positions

all_positions = (cg0_positions + cg1_positions).sort
assert_equal [0, 1, 2, 3], all_positions

# Verify all instance IDs are unique
all_instance_ids = Karafka::App.consumer_groups.flat_map do |cg|
  cg.subscription_groups.map { |sg| sg.kafka[:"group.instance.id"] }
end

assert_equal 4, all_instance_ids.uniq.size

# Multiple redraws should not change anything
5.times do
  draw_routes(create_topics: false) do
    # Empty
  end
end

assert_equal 2, cg0.subscription_groups.size
assert_equal 2, cg1.subscription_groups.size
assert_equal [0, 1], cg0.subscription_groups.map(&:position).sort
assert_equal [2, 3], cg1.subscription_groups.map(&:position).sort

# Verify instance ID format includes position
Karafka::App.consumer_groups.each do |cg|
  cg.subscription_groups.each do |sg|
    expected_suffix = "_#{sg.position}"
    assert sg.kafka[:"group.instance.id"].end_with?(expected_suffix)
  end
end
