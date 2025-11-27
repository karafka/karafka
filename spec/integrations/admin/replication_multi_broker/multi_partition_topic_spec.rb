# frozen_string_literal: true

# Test: Increase replication factor for a multi-partition topic
#
# This test verifies:
# 1. RF increase works correctly for topics with multiple partitions
# 2. Each partition gets the correct replica assignment
# 3. Data in all partitions is preserved
#
# REQUIRES: 3-broker Kafka cluster (docker-compose.multi-broker.yml)

require 'tempfile'
require 'securerandom'
require 'timeout'

# Skip checks
docker_available = system('docker --version > /dev/null 2>&1')
kafka_container_running = docker_available && system('docker exec kafka1 true > /dev/null 2>&1')

unless docker_available && kafka_container_running
  puts 'Skipping: Docker or kafka1 container not available'
  exit 0
end

setup_karafka

class MultiPartitionConsumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(MultiPartitionConsumer)

# Check broker count
cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

unless broker_count >= 3
  puts "Skipping: Need 3+ brokers, found #{broker_count}"
  exit 0
end

DT[:broker_count] = broker_count

# Create topic with multiple partitions and RF=1
test_topic = "it-multi-partition-#{SecureRandom.uuid}"
partition_count = 3
initial_rf = 1
target_rf = 3

begin
  Karafka::Admin.create_topic(test_topic, partition_count, initial_rf)
  sleep(3)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

DT[:partition_count] = partition_count

# Produce messages to each partition using keys for deterministic routing
messages_by_partition = {}
partition_count.times do |partition|
  messages_by_partition[partition] = []
  3.times do |i|
    msg = "partition-#{partition}-msg-#{i}-#{SecureRandom.hex(4)}"
    messages_by_partition[partition] << msg
    # Use partition parameter directly
    produce(test_topic, msg, partition: partition)
  end
end

sleep(2)

DT[:messages_produced] = messages_by_partition.values.flatten.size

# Verify initial state - all partitions should have RF=1
initial_info = Karafka::Admin::Topics.info(test_topic)

assert_equal(
  partition_count,
  initial_info[:partitions].size,
  "Should have #{partition_count} partitions"
)

initial_info[:partitions].each do |partition|
  partition_id = partition[:partition_id]
  replica_count = partition[:replica_count] || partition[:replicas]&.size

  assert_equal(
    initial_rf,
    replica_count,
    "Partition #{partition_id} should start with RF=#{initial_rf}"
  )
end

# Generate plan
plan = Karafka::Admin.plan_topic_replication(
  topic: test_topic,
  replication_factor: target_rf
)

DT[:plan_generated] = true

# Verify plan covers all partitions
assert_equal(
  partition_count,
  plan.partitions_assignment.size,
  'Plan should cover all partitions'
)

plan.partitions_assignment.each do |partition_id, broker_ids|
  assert_equal(
    target_rf,
    broker_ids.size,
    "Partition #{partition_id} should be assigned #{target_rf} brokers"
  )

  # No duplicate brokers per partition
  assert_equal(
    broker_ids.uniq.size,
    broker_ids.size,
    "Partition #{partition_id} should have unique brokers"
  )
end

# Execute the plan
temp_file = Tempfile.new(['multi_partition', '.json'])

begin
  plan.export_to_file(temp_file.path)
  File.chmod(0o644, temp_file.path)
  container_path = "/tmp/karafka_multi_part_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`
  `docker exec kafka1 chmod 644 #{container_path} 2>/dev/null`

  execute_cmd = <<~CMD
    docker exec kafka1 kafka-reassign-partitions \
      --bootstrap-server kafka1:29092 \
      --reassignment-json-file #{container_path} \
      --execute
  CMD

  execute_output = `#{execute_cmd} 2>&1`
  DT[:execute_output] = execute_output

  # Wait for completion
  Timeout.timeout(300) do
    loop do
      verify_output = `docker exec kafka1 kafka-reassign-partitions \
        --bootstrap-server kafka1:29092 \
        --reassignment-json-file #{container_path} \
        --verify 2>&1`

      break if verify_output.include?('completed') && !verify_output.include?('still in progress')

      puts 'Multi-partition reassignment in progress...'
      sleep(5)
    end
  end

  `docker exec kafka1 rm #{container_path} 2>/dev/null`

ensure
  temp_file.close
  temp_file.unlink
end

sleep(5)

# Verify final state - all partitions should have RF=target_rf
final_info = Karafka::Admin::Topics.info(test_topic)

final_info[:partitions].each do |partition|
  partition_id = partition[:partition_id]
  replica_count = partition[:replica_count] || partition[:replicas]&.size

  assert_equal(
    target_rf,
    replica_count,
    "Partition #{partition_id} should have RF=#{target_rf}, got #{replica_count}"
  )

  DT["partition_#{partition_id}_rf"] = replica_count
end

DT[:all_partitions_verified] = true

# Verify data integrity for each partition
partition_count.times do |partition|
  partition_messages = Karafka::Admin.read_topic(test_topic, partition, 100, 0)
  partition_payloads = partition_messages.map(&:raw_payload)

  expected_messages = messages_by_partition[partition]
  expected_messages.each do |msg|
    assert(
      partition_payloads.include?(msg),
      "Message '#{msg}' should be in partition #{partition}"
    )
  end

  DT["partition_#{partition}_data_verified"] = true
end

# Clean up
begin
  Karafka::Admin.delete_topic(test_topic)
rescue StandardError
  # Ignore cleanup errors
end

puts "SUCCESS: Multi-partition topic RF increased from #{initial_rf} to #{target_rf}"
puts "All #{partition_count} partitions now have RF=#{target_rf}"
puts 'Data integrity verified for all partitions'
