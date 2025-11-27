# frozen_string_literal: true

# End-to-end test: Increase replication factor using kafka-reassign-partitions.sh
#
# This test verifies the complete workflow:
# 1. Create topic with RF=1
# 2. Produce test data
# 3. Generate replication increase plan (RF=1 → RF=3)
# 4. Execute plan via kafka-reassign-partitions.sh
# 5. Wait for reassignment to complete
# 6. Verify RF=3 via Admin metadata
# 7. Verify data integrity (messages still accessible)
#
# REQUIRES: 3-broker Kafka cluster (docker-compose.multi-broker.yml)

require 'tempfile'
require 'securerandom'
require 'timeout'

# Skip if Docker is not available
docker_available = system('docker --version > /dev/null 2>&1')

unless docker_available
  puts 'Skipping: Docker not available'
  exit 0
end

# Check for multi-broker container (kafka1 from docker-compose.multi-broker.yml)
kafka_container_running = system('docker exec kafka1 true > /dev/null 2>&1')

unless kafka_container_running
  puts 'Skipping: kafka1 container not running (multi-broker cluster required)'
  exit 0
end

setup_karafka

class IncreaseRfConsumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(IncreaseRfConsumer)

# Check broker count
cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

unless broker_count >= 3
  puts "Skipping: Need 3+ brokers, found #{broker_count}"
  exit 0
end

DT[:broker_count] = broker_count

# Create test topic with RF=1
# Use unique topic name to avoid stale metadata from previous runs
test_topic = "it-rf-increase-#{SecureRandom.uuid}"
partition_count = 1 # Single partition to avoid metadata caching issues
initial_rf = 1
target_rf = 3

begin
  Karafka::Admin.create_topic(test_topic, partition_count, initial_rf)
  sleep(3) # Allow metadata propagation
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

# Produce test messages
test_messages = 10.times.map { |i| "message-#{i}-#{SecureRandom.hex(8)}" }
test_messages.each do |msg|
  produce(test_topic, msg)
end

sleep(1) # Allow messages to be committed

# Verify initial state
initial_topic_info = Karafka::Admin::Topics.info(test_topic)
initial_partition = initial_topic_info[:partitions].first
actual_initial_rf = initial_partition[:replica_count] || initial_partition[:replicas]&.size

assert_equal(
  initial_rf,
  actual_initial_rf,
  "Initial RF should be #{initial_rf}, got #{actual_initial_rf}"
)

DT[:initial_rf] = actual_initial_rf

# Read messages before RF change for data integrity check
messages_before = Karafka::Admin.read_topic(test_topic, 0, 100, 0).map(&:raw_payload)

DT[:messages_before_count] = messages_before.size

assert_equal(
  test_messages.size,
  messages_before.size,
  "Should have #{test_messages.size} messages before RF change, got #{messages_before.size}"
)

# Generate replication increase plan
plan = Karafka::Admin.plan_topic_replication(
  topic: test_topic,
  replication_factor: target_rf
)

DT[:plan_generated] = true
DT[:plan_summary] = plan.summary

# Validate plan structure
assert_equal(test_topic, plan.topic, 'Plan topic mismatch')
assert_equal(initial_rf, plan.current_replication_factor, 'Current RF mismatch')
assert_equal(target_rf, plan.target_replication_factor, 'Target RF mismatch')

# Each partition should have target_rf brokers assigned
plan.partitions_assignment.each do |partition_id, broker_ids|
  assert_equal(
    target_rf,
    broker_ids.size,
    "Partition #{partition_id} should have #{target_rf} brokers, got #{broker_ids.size}"
  )

  # No duplicate brokers
  assert_equal(
    broker_ids.uniq.size,
    broker_ids.size,
    "Partition #{partition_id} has duplicate brokers: #{broker_ids}"
  )
end

# Export plan to temp file
temp_file = Tempfile.new(['rf_increase', '.json'])

begin
  plan.export_to_file(temp_file.path)
  # Make file world-readable for Docker container access
  File.chmod(0o644, temp_file.path)

  # Copy to kafka1 container
  container_path = "/tmp/karafka_rf_increase_#{SecureRandom.hex(4)}.json"
  copy_result = `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`

  unless $?.success?
    puts "Failed to copy file to container: #{copy_result}"
    exit 1
  end

  # Ensure file is readable inside container
  `docker exec kafka1 chmod 644 #{container_path} 2>/dev/null`

  # Execute kafka-reassign-partitions.sh
  # Use internal listener (kafka1:29092) for inter-broker communication
  execute_cmd = <<~CMD
    docker exec kafka1 kafka-reassign-partitions \
      --bootstrap-server kafka1:29092 \
      --reassignment-json-file #{container_path} \
      --execute
  CMD

  execute_output = `#{execute_cmd} 2>&1`
  DT[:execute_output] = execute_output

  # Check execution was accepted
  assert(
    execute_output.include?('Successfully started') ||
    execute_output.include?('Current partition replica assignment'),
    "Reassignment should start. Output: #{execute_output}"
  )

  # Wait for reassignment to complete (with timeout)
  reassignment_complete = false
  verify_output = nil

  Timeout.timeout(180) do # 3 minutes max
    loop do
      verify_cmd = <<~CMD
        docker exec kafka1 kafka-reassign-partitions \
          --bootstrap-server kafka1:29092 \
          --reassignment-json-file #{container_path} \
          --verify
      CMD

      verify_output = `#{verify_cmd} 2>&1`

      # Check if all partitions are complete
      if verify_output.include?('Reassignment of partition') &&
         !verify_output.include?('still in progress')
        reassignment_complete = true
        DT[:verify_output] = verify_output
        break
      end

      puts 'Reassignment in progress, waiting...'
      sleep(5)
    end
  end

  assert(reassignment_complete, "Reassignment should complete within timeout. Output: #{verify_output}")

  # Clean up container file
  `docker exec kafka1 rm #{container_path} 2>/dev/null`

ensure
  temp_file.close
  temp_file.unlink
end

# Allow metadata to propagate
sleep(3)

# Verify final state - RF should now be target_rf
final_topic_info = Karafka::Admin::Topics.info(test_topic)
final_partitions = final_topic_info[:partitions]

# Check RF for each partition
final_partitions.each do |partition|
  partition_id = partition[:partition_id]
  replica_count = partition[:replica_count] || partition[:replicas]&.size

  assert_equal(
    target_rf,
    replica_count,
    "Partition #{partition_id} should have RF=#{target_rf}, got #{replica_count}"
  )

  DT["partition_#{partition_id}_final_rf"] = replica_count
end

DT[:final_rf_verified] = true

# Verify data integrity - all messages should still be accessible
messages_after = Karafka::Admin.read_topic(test_topic, 0, 100, 0).map(&:raw_payload)

DT[:messages_after_count] = messages_after.size

assert_equal(
  messages_before.size,
  messages_after.size,
  "Message count should be preserved: before=#{messages_before.size}, after=#{messages_after.size}"
)

# All original messages should be present
test_messages.each do |original_msg|
  assert(
    messages_after.include?(original_msg),
    "Message '#{original_msg}' should be present after RF increase"
  )
end

DT[:data_integrity_verified] = true

# Verify cluster still functional - produce and consume new message
new_message = "post-rf-change-#{SecureRandom.hex(8)}"
produce(test_topic, new_message)
sleep(1)

post_messages = Karafka::Admin.read_topic(test_topic, 0, 100, 0)
assert(
  post_messages.any? { |m| m.raw_payload == new_message },
  'Should be able to produce/consume after RF change'
)

# Clean up test topic
begin
  Karafka::Admin.delete_topic(test_topic)
rescue StandardError
  # Ignore cleanup errors
end

DT[:post_change_produce_consume_verified] = true

puts "SUCCESS: Replication increased from RF=#{initial_rf} to RF=#{target_rf}"
puts "Verified #{messages_after.size} messages after reassignment"
puts "Cluster functional - new messages can be produced and consumed"
