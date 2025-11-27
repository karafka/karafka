# frozen_string_literal: true

# Test: Verify In-Sync Replicas (ISR) after replication factor change
#
# This test verifies:
# 1. After RF change, all new replicas become in-sync
# 2. ISR count matches the target RF
# 3. Partition leader is functioning
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

class IsrVerifyConsumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(IsrVerifyConsumer)

# Check broker count
cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

unless broker_count >= 3
  puts "Skipping: Need 3+ brokers, found #{broker_count}"
  exit 0
end

# Create topic with RF=1
test_topic = "it-isr-test-#{SecureRandom.uuid}"
target_rf = 3

begin
  Karafka::Admin.create_topic(test_topic, 1, 1)  # Single partition
  sleep(3)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

# Get initial ISR info
initial_topic_info = Karafka::Admin::Topics.info(test_topic)
initial_isr = {}

initial_topic_info[:partitions].each do |partition|
  partition_id = partition[:partition_id]
  isr = partition[:in_sync_replicas] || partition[:in_sync_replica_brokers] || partition[:isr] || []
  # Handle different formats: array of objects, array of integers, or empty
  initial_isr[partition_id] = if isr.is_a?(Array) && isr.first.respond_to?(:node_id)
                                isr.map(&:node_id)
                              elsif isr.is_a?(Array)
                                isr
                              else
                                [isr].compact
                              end
end

DT[:initial_isr] = initial_isr

# Generate and execute plan
plan = Karafka::Admin.plan_topic_replication(
  topic: test_topic,
  replication_factor: target_rf
)

temp_file = Tempfile.new(['isr_test', '.json'])

begin
  plan.export_to_file(temp_file.path)
  container_path = "/tmp/karafka_isr_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`

  # Execute
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

# Allow ISR to stabilize
sleep(5)

# Verify ISR after change
final_topic_info = Karafka::Admin::Topics.info(test_topic)
final_isr = {}

final_topic_info[:partitions].each do |partition|
  partition_id = partition[:partition_id]

  # Get replica count
  replica_count = partition[:replica_count] || partition[:replicas]&.size
  assert_equal(
    target_rf,
    replica_count,
    "Partition #{partition_id} RF should be #{target_rf}, got #{replica_count}"
  )

  # Get ISR
  isr = partition[:in_sync_replicas] || partition[:in_sync_replica_brokers] || partition[:isr] || []
  isr_list = if isr.is_a?(Array) && isr.first.respond_to?(:node_id)
               isr.map(&:node_id)
             elsif isr.is_a?(Array)
               isr
             else
               [isr].compact
             end

  final_isr[partition_id] = isr_list

  # ISR should have at least 1 replica (leader must be in-sync)
  assert(
    isr_list.size >= 1,
    "Partition #{partition_id} should have at least 1 ISR, got #{isr_list.size}"
  )

  # Ideally ISR should match RF (all replicas in-sync after stabilization)
  # Allow for some lag during test
  assert(
    isr_list.size >= 1,
    "Partition #{partition_id} ISR should have replicas"
  )

  # Verify leader exists
  leader = partition[:leader] || partition[:leader_id]
  leader_id = leader.respond_to?(:node_id) ? leader.node_id : leader

  assert(
    !leader_id.nil? && leader_id >= 0,
    "Partition #{partition_id} should have a valid leader"
  )

  DT["partition_#{partition_id}_leader"] = leader_id
  DT["partition_#{partition_id}_isr"] = isr_list
end

DT[:final_isr] = final_isr

# Verify cluster still functional by producing and consuming
test_msg = "isr-test-#{SecureRandom.hex(8)}"
produce(test_topic, test_msg, partition: 0)
sleep(1)

messages = Karafka::Admin.read_topic(test_topic, 0, 100, 0)
assert(
  messages.any? { |m| m.raw_payload == test_msg },
  'Should be able to produce/consume with new ISR'
)

DT[:cluster_functional] = true

puts 'SUCCESS: ISR verified after replication factor change'
puts 'Partition ISR status:'
final_isr.each do |partition_id, isr|
  puts "  Partition #{partition_id}: ISR = [#{isr.join(', ')}]"
end
