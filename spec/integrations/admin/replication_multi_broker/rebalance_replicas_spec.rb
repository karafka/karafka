# frozen_string_literal: true

# Test: Rebalance existing replicas across brokers
#
# This test verifies:
# 1. Rebalance generates a plan without changing replication factor
# 2. The plan can be executed via kafka-reassign-partitions
# 3. Data integrity is maintained after rebalancing
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

class RebalanceConsumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(RebalanceConsumer)

# Check broker count
cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

unless broker_count >= 3
  puts "Skipping: Need 3+ brokers, found #{broker_count}"
  exit 0
end

DT[:broker_count] = broker_count

# Create topic with RF=2 (so we have replicas to rebalance)
test_topic = "it-rebalance-#{SecureRandom.uuid}"
partition_count = 1
initial_rf = 2

begin
  Karafka::Admin.create_topic(test_topic, partition_count, initial_rf)
  sleep(3)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

# Produce test messages
test_messages = 5.times.map { |i| "rebalance-msg-#{i}-#{SecureRandom.hex(8)}" }
test_messages.each do |msg|
  produce(test_topic, msg)
end

sleep(1)

# Get initial replica assignment
initial_topic_info = Karafka::Admin::Topics.info(test_topic)
initial_partition = initial_topic_info[:partitions].first
initial_replicas = initial_partition[:replicas] || initial_partition[:replica_brokers] || []
initial_replica_ids = if initial_replicas.first.respond_to?(:node_id)
                        initial_replicas.map(&:node_id).sort
                      else
                        initial_replicas.sort
                      end

DT[:initial_replicas] = initial_replica_ids
DT[:initial_rf] = initial_replica_ids.size

# Generate rebalance plan
plan = Karafka::Admin::Replication.rebalance(topic: test_topic)

DT[:plan_generated] = true
DT[:plan_current_rf] = plan.current_replication_factor
DT[:plan_target_rf] = plan.target_replication_factor

# Verify rebalance maintains same RF
assert_equal(
  initial_rf,
  plan.current_replication_factor,
  'Rebalance should report correct current RF'
)

assert_equal(
  initial_rf,
  plan.target_replication_factor,
  'Rebalance should maintain same RF'
)

# Verify plan has correct structure
assert_equal(
  partition_count,
  plan.partitions_assignment.size,
  'Plan should cover all partitions'
)

plan.partitions_assignment.each do |partition_id, broker_ids|
  assert_equal(
    initial_rf,
    broker_ids.size,
    "Partition #{partition_id} should have #{initial_rf} replicas"
  )
end

# Execute the rebalance plan
temp_file = Tempfile.new(['rebalance', '.json'])

begin
  plan.export_to_file(temp_file.path)
  File.chmod(0o644, temp_file.path)
  container_path = "/tmp/karafka_rebalance_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`
  `docker exec kafka1 chmod 644 #{container_path} 2>/dev/null`

  # Execute
  execute_cmd = <<~CMD
    docker exec kafka1 kafka-reassign-partitions \
      --bootstrap-server kafka1:29092 \
      --reassignment-json-file #{container_path} \
      --execute
  CMD

  execute_output = `#{execute_cmd} 2>&1`
  DT[:execute_output] = execute_output

  # Wait for completion
  Timeout.timeout(120) do
    loop do
      verify_output = `docker exec kafka1 kafka-reassign-partitions \
        --bootstrap-server kafka1:29092 \
        --reassignment-json-file #{container_path} \
        --verify 2>&1`

      break if verify_output.include?('completed') && !verify_output.include?('still in progress')

      sleep(3)
    end
  end

  `docker exec kafka1 rm #{container_path} 2>/dev/null`

ensure
  temp_file.close
  temp_file.unlink
end

sleep(2)

# Verify RF unchanged after rebalance
final_topic_info = Karafka::Admin::Topics.info(test_topic)
final_partition = final_topic_info[:partitions].first
final_replica_count = final_partition[:replica_count] || final_partition[:replicas]&.size

assert_equal(
  initial_rf,
  final_replica_count,
  "RF should remain #{initial_rf} after rebalance"
)

DT[:final_rf] = final_replica_count

# Verify data integrity
messages_after = Karafka::Admin.read_topic(test_topic, 0, 100, 0).map(&:raw_payload)

test_messages.each do |msg|
  assert(
    messages_after.include?(msg),
    "Message '#{msg}' should be present after rebalance"
  )
end

DT[:data_integrity_verified] = true

# Clean up
begin
  Karafka::Admin.delete_topic(test_topic)
rescue StandardError
  # Ignore cleanup errors
end

puts 'SUCCESS: Rebalance completed without changing RF'
puts "RF maintained at #{final_replica_count}"
puts 'Data integrity verified'
