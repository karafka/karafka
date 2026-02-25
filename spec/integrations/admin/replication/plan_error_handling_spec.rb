# frozen_string_literal: true

# Karafka should validate replication plan parameters and provide clear errors

setup_karafka

class ReplicationErrorConsumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(ReplicationErrorConsumer)

# Create test topic with RF=1
test_topic = DT.topic

begin
  Karafka::Admin.create_topic(test_topic, 2, 1)
  sleep(0.5)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

# Get current state
topic_info = Karafka::Admin::Topics.info(test_topic)
current_rf = topic_info[:partitions].first[:replica_count]
cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

# Test 1: Same RF as current should fail
begin
  Karafka::Admin.plan_topic_replication(
    topic: test_topic,
    replication_factor: current_rf
  )

  DT[:same_rf_error] = false
rescue Karafka::Errors::InvalidConfigurationError => e
  DT[:same_rf_error] = true
  DT[:same_rf_message] = e.message
end

assert DT[:same_rf_error], "Should raise error when target RF equals current RF"
assert(
  DT[:same_rf_message].include?("must be higher than current"),
  "Error message should explain the issue"
)

# Test 2: RF exceeding broker count should fail
begin
  Karafka::Admin.plan_topic_replication(
    topic: test_topic,
    replication_factor: broker_count + 10
  )

  DT[:exceeds_brokers_error] = false
rescue Karafka::Errors::InvalidConfigurationError => e
  DT[:exceeds_brokers_error] = true
  DT[:exceeds_brokers_message] = e.message
end

assert(
  DT[:exceeds_brokers_error],
  "Should raise error when target RF exceeds available brokers"
)
assert(
  DT[:exceeds_brokers_message].include?("exceed available broker count"),
  "Error message should explain broker limitation"
)

# Test 3: Invalid topic name format (empty string)
begin
  result = Karafka::Admin::Contracts::Replication.new.call(
    topic: "",
    to: 2
  )

  DT[:invalid_topic_error] = !result.success?
rescue
  DT[:invalid_topic_error] = true
end

assert DT[:invalid_topic_error], "Should raise error for empty topic name"

# Test 4: Invalid RF value (zero)
begin
  result = Karafka::Admin::Contracts::Replication.new.call(
    topic: test_topic,
    to: 0
  )

  DT[:invalid_rf_error] = !result.success?
rescue
  DT[:invalid_rf_error] = true
end

assert DT[:invalid_rf_error], "Should raise error for RF less than 1"
