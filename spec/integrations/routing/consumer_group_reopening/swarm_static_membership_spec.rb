# frozen_string_literal: true

# When using static group membership in swarm mode with consumer group reopening,
# the group.instance.id values should remain stable across multiple draw calls.
# This ensures no fencing issues occur when consumer groups are reopened.
# Ref: https://github.com/karafka/karafka/issues/2915

setup_karafka do |config|
  config.swarm.nodes = 2
  # Configure static group membership
  config.kafka[:'group.instance.id'] = 'test-static-instance'
end

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)
Consumer3 = Class.new(Karafka::BaseConsumer)

# First draw - define first consumer group with one topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer1
    end
  end
end

# Second draw - define second consumer group with one topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[1] do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

# Capture state after initial draws
group1 = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[0] }
group2 = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[1] }

sg1_initial = group1.subscription_groups.first
sg2_initial = group2.subscription_groups.first

sg1_initial_id = sg1_initial.id
sg2_initial_id = sg2_initial.id
sg1_initial_instance_id = sg1_initial.kafka[:'group.instance.id']
sg2_initial_instance_id = sg2_initial.kafka[:'group.instance.id']

# Verify initial state - both groups should have unique instance IDs
unless sg1_initial_instance_id && sg2_initial_instance_id
  raise 'Both groups should have group.instance.id set'
end

raise 'Instance IDs should be different' if sg1_initial_instance_id == sg2_initial_instance_id

# Third draw - reopen first consumer group and add another topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[2] do
      consumer Consumer3
    end
  end
end

# Verify subscription groups were rebuilt for group1
sg1_after = group1.subscription_groups.first
sg2_after = group2.subscription_groups.first

# Group1's subscription group should be stable
assert_equal sg1_initial_id, sg1_after.id, 'Group1 subscription group ID should remain stable'
assert_equal(
  sg1_initial_instance_id,
  sg1_after.kafka[:'group.instance.id'],
  'Group1 group.instance.id should remain stable'
)

# Group1 should now have both topics
assert_equal 2, sg1_after.topics.size
assert_equal [DT.topics[0], DT.topics[2]].sort, sg1_after.topics.map(&:name).sort

# Group2 should remain unchanged
assert_equal sg2_initial_id, sg2_after.id, 'Group2 subscription group ID should remain unchanged'
assert_equal(
  sg2_initial_instance_id,
  sg2_after.kafka[:'group.instance.id'],
  'Group2 group.instance.id should remain unchanged'
)

# Verify instance IDs are still different
sg1_final_instance_id = sg1_after.kafka[:'group.instance.id']
sg2_final_instance_id = sg2_after.kafka[:'group.instance.id']
raise 'Instance IDs should still be different' if sg1_final_instance_id == sg2_final_instance_id
