# frozen_string_literal: true

# When using static group membership with consumer group reopening, the subscription group
# positions and resulting group.instance.id values should remain stable
# This is critical for swarm mode where position affects the group.instance.id
# Ref: https://github.com/karafka/karafka/issues/2915

setup_karafka do |config|
  # Configure static group membership
  config.kafka[:"group.instance.id"] = "test-instance"
end

Consumer1 = Class.new(Karafka::BaseConsumer)
Consumer2 = Class.new(Karafka::BaseConsumer)

# First draw - define consumer group with one topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer1
    end
  end
end

# Capture the subscription group details after first draw
group = Karafka::App.routes.find { |cg| cg.name == DT.consumer_groups[0] }
first_sg = group.subscription_groups.first
first_sg_id = first_sg.id
first_sg_kafka = first_sg.kafka.dup
first_group_instance_id = first_sg_kafka[:"group.instance.id"]

# Verify static membership is configured
raise "group.instance.id should be set" unless first_group_instance_id
raise "group.instance.id should include position" unless first_group_instance_id.include?("_0")

# Second draw - reopen consumer group and add another topic
draw_routes(create_topics: false) do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

# Verify subscription groups were rebuilt
assert_equal 2, group.topics.size
assert_equal 1, group.subscription_groups.size

second_sg = group.subscription_groups.first
second_sg_id = second_sg.id
second_sg_kafka = second_sg.kafka.dup
second_group_instance_id = second_sg_kafka[:"group.instance.id"]

# The subscription group ID should remain stable (same position)
# This is critical for static group membership consistency
assert_equal first_sg_id, second_sg_id, "Subscription group ID should remain stable"

# The group.instance.id should remain stable (same position suffix)
assert_equal(
  first_group_instance_id,
  second_group_instance_id,
  "group.instance.id should remain stable after reopening for static membership"
)

# Verify both topics are now in the subscription group
topic_names = second_sg.topics.map(&:name).sort
assert_equal [DT.topics[0], DT.topics[1]].sort, topic_names
