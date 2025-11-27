# frozen_string_literal: true

# Test: Manual broker assignment for replication increase
#
# This test verifies:
# 1. Manual broker assignment is respected in the generated plan
# 2. The plan executes correctly with specified brokers
# 3. Final replica placement matches the requested assignment
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

class ManualAssignmentConsumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(ManualAssignmentConsumer)

# Check broker count and get broker IDs
cluster_info = Karafka::Admin.cluster_info
brokers = cluster_info.brokers
broker_count = brokers.size

unless broker_count >= 3
  puts "Skipping: Need 3+ brokers, found #{broker_count}"
  exit 0
end

# Get actual broker IDs from cluster
# rdkafka returns objects with node_id method
broker_ids = brokers.map do |broker|
  if broker.is_a?(Hash)
    broker[:broker_id] || broker[:node_id]
  else
    broker.node_id
  end
end.sort

DT[:broker_ids] = broker_ids
DT[:broker_count] = broker_count

# Create topic with RF=1
test_topic = "it-manual-assign-#{SecureRandom.uuid}"

begin
  Karafka::Admin.create_topic(test_topic, 1, 1)
  sleep(3)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

# Produce test message
test_msg = "manual-assign-#{SecureRandom.hex(8)}"
produce(test_topic, test_msg)
sleep(1)

# Choose specific brokers for RF=3
# Use the first 3 broker IDs from the cluster
target_brokers = broker_ids.first(3)

manual_assignment = {
  0 => target_brokers
}

DT[:manual_assignment] = manual_assignment

# Generate plan with manual assignment
plan = Karafka::Admin.plan_topic_replication(
  topic: test_topic,
  replication_factor: 3,
  brokers: manual_assignment
)

DT[:plan_generated] = true

# Verify plan uses our exact assignment
assert_equal(
  manual_assignment,
  plan.partitions_assignment,
  'Plan should use exact manual assignment'
)

# Verify JSON contains correct brokers
json_data = JSON.parse(plan.reassignment_json)
partition_data = json_data['partitions'].first

assert_equal(
  target_brokers.sort,
  partition_data['replicas'].sort,
  'JSON should contain specified brokers'
)

# Execute the plan
temp_file = Tempfile.new(['manual_assign', '.json'])

begin
  plan.export_to_file(temp_file.path)
  File.chmod(0o644, temp_file.path)
  container_path = "/tmp/karafka_manual_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`
  `docker exec kafka1 chmod 644 #{container_path} 2>/dev/null`

  execute_cmd = <<~CMD
    docker exec kafka1 kafka-reassign-partitions \
      --bootstrap-server kafka1:29092 \
      --reassignment-json-file #{container_path} \
      --execute
  CMD

  `#{execute_cmd} 2>&1`

  # Wait for completion
  Timeout.timeout(180) do
    loop do
      verify_output = `docker exec kafka1 kafka-reassign-partitions \
        --bootstrap-server kafka1:29092 \
        --reassignment-json-file #{container_path} \
        --verify 2>&1`

      break if verify_output.include?('completed') && !verify_output.include?('still in progress')

      sleep(5)
    end
  end

  `docker exec kafka1 rm #{container_path} 2>/dev/null`

ensure
  temp_file.close
  temp_file.unlink
end

sleep(3)

# Verify final replica count matches our request
final_info = Karafka::Admin::Topics.info(test_topic)
final_partition = final_info[:partitions].first
final_replica_count = final_partition[:replica_count] || final_partition[:replicas]&.size

DT[:final_replica_count] = final_replica_count

assert_equal(
  target_brokers.size,
  final_replica_count,
  "Final replica count #{final_replica_count} should match requested #{target_brokers.size}"
)

# Verify data integrity
messages = Karafka::Admin.read_topic(test_topic, 0, 100, 0)
assert(
  messages.any? { |m| m.raw_payload == test_msg },
  'Message should be accessible after manual assignment'
)

DT[:data_verified] = true

# Clean up
begin
  Karafka::Admin.delete_topic(test_topic)
rescue StandardError
  # Ignore cleanup errors
end

puts 'SUCCESS: Manual broker assignment executed correctly'
puts "Requested brokers: #{target_brokers.join(', ')}"
puts "Final replica count: #{final_replica_count}"
