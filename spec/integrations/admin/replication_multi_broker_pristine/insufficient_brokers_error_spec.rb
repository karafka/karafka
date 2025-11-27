# frozen_string_literal: true

# Test: Error handling when target RF exceeds available brokers
#
# This test verifies:
# 1. Karafka properly validates target RF against broker count
# 2. Appropriate error is raised when RF > broker count
# 3. Error message is informative
#
# REQUIRES: 3-broker Kafka cluster (docker-compose.multi-broker.yml)

require 'securerandom'

# Skip checks
docker_available = system('docker --version > /dev/null 2>&1')
kafka_container_running = docker_available && system('docker exec kafka1 true > /dev/null 2>&1')

unless docker_available && kafka_container_running
  puts 'Skipping: Docker or kafka1 container not available'
  exit 0
end

setup_karafka

class InsufficientBrokersConsumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(InsufficientBrokersConsumer)

# Check broker count
cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

unless broker_count >= 3
  puts "Skipping: Need 3+ brokers, found #{broker_count}"
  exit 0
end

DT[:broker_count] = broker_count

# Create topic with RF=1
test_topic = DT.topic

begin
  Karafka::Admin.create_topic(test_topic, 2, 1)
  sleep(1)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

# Test 1: Try to set RF higher than broker count
invalid_rf = broker_count + 5

error_raised = false
error_message = nil

begin
  Karafka::Admin.plan_topic_replication(
    topic: test_topic,
    replication_factor: invalid_rf
  )
rescue Karafka::Errors::InvalidConfigurationError => e
  error_raised = true
  error_message = e.message
end

DT[:error_raised_for_high_rf] = error_raised
DT[:error_message] = error_message

assert(
  error_raised,
  "Should raise error when RF (#{invalid_rf}) > broker count (#{broker_count})"
)

assert(
  error_message.include?('broker') || error_message.include?('exceed'),
  "Error message should mention brokers: #{error_message}"
)

# Test 2: RF equal to current should fail (no change)
current_topic_info = Karafka::Admin::Topics.info(test_topic)
current_rf = current_topic_info[:partitions].first[:replica_count] ||
             current_topic_info[:partitions].first[:replicas]&.size

error_raised_same_rf = false

begin
  Karafka::Admin.plan_topic_replication(
    topic: test_topic,
    replication_factor: current_rf
  )
rescue Karafka::Errors::InvalidConfigurationError
  error_raised_same_rf = true
end

DT[:error_raised_for_same_rf] = error_raised_same_rf

assert(
  error_raised_same_rf,
  'Should raise error when target RF equals current RF'
)

# Test 3: RF lower than current should fail (plan() is for increase only)
error_raised_lower_rf = false

begin
  Karafka::Admin.plan_topic_replication(
    topic: test_topic,
    replication_factor: 0
  )
rescue Karafka::Errors::InvalidConfigurationError
  error_raised_lower_rf = true
end

DT[:error_raised_for_lower_rf] = error_raised_lower_rf

assert(
  error_raised_lower_rf,
  'Should raise error when target RF is less than 1'
)

# Test 4: Valid RF should work (sanity check)
valid_plan_created = false

begin
  plan = Karafka::Admin.plan_topic_replication(
    topic: test_topic,
    replication_factor: [broker_count, 3].min  # Max of available brokers or 3
  )
  valid_plan_created = !plan.nil?
rescue Karafka::Errors::InvalidConfigurationError
  valid_plan_created = false
end

DT[:valid_plan_created] = valid_plan_created

assert(
  valid_plan_created,
  'Valid RF within broker count should create plan'
)

puts 'SUCCESS: Insufficient brokers error handling works correctly'
puts "Broker count: #{broker_count}"
puts "Correctly rejected RF=#{invalid_rf} (exceeds brokers)"
puts "Correctly rejected RF=#{current_rf} (same as current)"
puts 'Correctly rejected RF=0 (invalid)'
