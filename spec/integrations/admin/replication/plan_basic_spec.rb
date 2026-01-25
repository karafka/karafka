# frozen_string_literal: true

# Karafka should generate basic replication plans with correct structure

setup_karafka

class ReplicationBasicConsumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(ReplicationBasicConsumer)

# Create test topic
test_topic = DT.topic

begin
  Karafka::Admin.create_topic(test_topic, 2, 1)
  sleep(0.5)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

# Get cluster info
cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

# Generate plan (rebalance for single broker, increase for multi-broker)
plan = if broker_count >= 2
  Karafka::Admin.plan_topic_replication(
    topic: test_topic,
    replication_factor: 2
  )
else
  Karafka::Admin::Replication.rebalance(topic: test_topic)
end

# Store plan details
DT[:plan] = plan
DT[:broker_count] = broker_count

# Validate basic plan structure
assert plan.topic == test_topic, "Plan should reference correct topic"
assert plan.current_replication_factor >= 1, "Should have current RF"
assert plan.target_replication_factor >= 1, "Should have target RF"
assert !plan.reassignment_json.nil?, "Should generate JSON"
assert !plan.execution_commands.nil?, "Should provide commands"
assert !plan.steps.nil?, "Should provide steps"

# Validate JSON structure
json_data = JSON.parse(plan.reassignment_json)
assert json_data["version"] == 1, "JSON version should be 1"
assert json_data.key?("partitions"), "JSON should have partitions array"
assert json_data["partitions"].size >= 1, "JSON should include partitions"

# Each partition entry should be valid
json_data["partitions"].each do |partition|
  assert partition.key?("topic"), "Partition should have topic"
  assert partition.key?("partition"), "Partition should have partition ID"
  assert partition.key?("replicas"), "Partition should have replicas array"
  assert partition["topic"] == test_topic, "Partition should reference correct topic"
end

# Validate execution commands
commands = plan.execution_commands
assert commands.key?(:generate), "Should provide generate command"
assert commands.key?(:execute), "Should provide execute command"
assert commands.key?(:verify), "Should provide verify command"

commands.values.each do |command|
  assert(
    command.include?("kafka-reassign-partitions"),
    "Commands should use kafka-reassign-partitions"
  )
end

# Validate summary
summary = plan.summary
assert !summary.empty?, "Summary should have content"
assert summary.include?(test_topic), "Summary should mention topic"
assert summary.include?("replication"), "Summary should mention replication"
