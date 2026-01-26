# frozen_string_literal: true

# Karafka should support manual broker assignment for replication plans

setup_karafka

class ReplicationManualConsumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(ReplicationManualConsumer)

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
broker_ids = cluster_info.brokers.map do |broker|
  broker.is_a?(Hash) ? broker[:node_id] : broker.node_id
end.sort

# Only test manual assignment if we have multiple brokers
if broker_ids.size >= 3
  # Create manual broker assignment
  manual_assignment = {
    0 => [broker_ids[0], broker_ids[1], broker_ids[2]],
    1 => [broker_ids[1], broker_ids[2], broker_ids[0]]
  }

  # Generate plan with manual assignment
  plan = Karafka::Admin.plan_topic_replication(
    topic: test_topic,
    replication_factor: 3,
    brokers: manual_assignment
  )

  # Validate plan uses manual assignment
  assert(
    plan.partitions_assignment == manual_assignment,
    "Plan should use provided manual assignment"
  )
  assert plan.target_replication_factor == 3, "Should have target RF of 3"

  # Test validation: missing partitions
  begin
    Karafka::Admin.plan_topic_replication(
      topic: test_topic,
      replication_factor: 3,
      brokers: { 0 => [broker_ids[0], broker_ids[1], broker_ids[2]] } # Missing partition 1
    )

    DT[:missing_partitions_error] = false
  rescue Karafka::Errors::InvalidConfigurationError => e
    DT[:missing_partitions_error] = true
    DT[:missing_partitions_message] = e.message
  end

  assert(
    DT[:missing_partitions_error],
    "Should raise error when partitions are missing"
  )
  assert(
    DT[:missing_partitions_message].include?("missing partitions"),
    "Error should mention missing partitions"
  )

  # Test validation: wrong broker count
  begin
    Karafka::Admin.plan_topic_replication(
      topic: test_topic,
      replication_factor: 3,
      brokers: {
        0 => [broker_ids[0], broker_ids[1]], # Only 2 brokers, need 3
        1 => [broker_ids[1], broker_ids[2], broker_ids[0]]
      }
    )

    DT[:wrong_count_error] = false
  rescue Karafka::Errors::InvalidConfigurationError => e
    DT[:wrong_count_error] = true
    DT[:wrong_count_message] = e.message
  end

  assert(
    DT[:wrong_count_error],
    "Should raise error when broker count does not match target RF"
  )
  assert(
    DT[:wrong_count_message].include?("does not match target replication factor"),
    "Error should mention broker count mismatch"
  )

  # Test validation: duplicate brokers
  begin
    Karafka::Admin.plan_topic_replication(
      topic: test_topic,
      replication_factor: 3,
      brokers: {
        0 => [broker_ids[0], broker_ids[0], broker_ids[1]], # Duplicate broker
        1 => [broker_ids[1], broker_ids[2], broker_ids[0]]
      }
    )

    DT[:duplicate_error] = false
  rescue Karafka::Errors::InvalidConfigurationError => e
    DT[:duplicate_error] = true
    DT[:duplicate_message] = e.message
  end

  assert DT[:duplicate_error], "Should raise error for duplicate brokers"
  assert(
    DT[:duplicate_message].include?("duplicate brokers"),
    "Error should mention duplicate brokers"
  )
else
  # Skip manual assignment tests for single/dual broker setups
  DT[:manual_skipped] = true
  assert true, "Manual assignment tests skipped (insufficient brokers)"
end
