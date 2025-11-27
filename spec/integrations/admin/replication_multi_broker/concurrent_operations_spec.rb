# frozen_string_literal: true

# Test: Concurrent replication changes on multiple topics
#
# This test verifies:
# 1. Multiple topics can have RF increased simultaneously
# 2. Each topic's reassignment completes independently
# 3. Data integrity maintained across all topics
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

class ConcurrentOpsConsumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(ConcurrentOpsConsumer)

# Check broker count
cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

unless broker_count >= 3
  puts "Skipping: Need 3+ brokers, found #{broker_count}"
  exit 0
end

# Create multiple test topics
topic_count = 3
test_topics = topic_count.times.map { "it-concurrent-#{SecureRandom.uuid}" }
target_rf = 3

test_topics.each do |topic|
  begin
    Karafka::Admin.create_topic(topic, 2, 1)
  rescue Rdkafka::RdkafkaError => e
    raise unless e.code == :topic_already_exists
  end
end

sleep(2)

# Produce test messages to each topic
messages_per_topic = {}
test_topics.each do |topic|
  messages = 5.times.map { |i| "msg-#{topic}-#{i}-#{SecureRandom.hex(8)}" }
  messages_per_topic[topic] = messages

  messages.each_with_index do |msg, i|
    produce(topic, msg, partition: i % 2)
  end
end

sleep(1)

# Generate plans for all topics
plans = {}
test_topics.each do |topic|
  plans[topic] = Karafka::Admin.plan_topic_replication(
    topic: topic,
    replication_factor: target_rf
  )
end

DT[:plans_generated] = plans.size

# Create combined reassignment JSON with all topics
all_partitions = []
plans.each do |topic, plan|
  JSON.parse(plan.reassignment_json)['partitions'].each do |partition|
    all_partitions << partition
  end
end

combined_json = JSON.pretty_generate({
                                       version: 1,
                                       partitions: all_partitions
                                     })

DT[:combined_partitions_count] = all_partitions.size

# Execute combined reassignment
temp_file = Tempfile.new(['concurrent', '.json'])

begin
  File.write(temp_file.path, combined_json)
  # Make file world-readable for Docker container access
  File.chmod(0o644, temp_file.path)
  container_path = "/tmp/karafka_concurrent_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`
  # Ensure file is readable inside container
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

  assert(
    execute_output.include?('Successfully started') ||
    execute_output.include?('Current partition replica assignment'),
    "Reassignment should start. Output: #{execute_output}"
  )

  # Wait for all to complete
  Timeout.timeout(300) do # 5 minutes for multiple topics
    loop do
      verify_output = `docker exec kafka1 kafka-reassign-partitions \
        --bootstrap-server kafka1:29092 \
        --reassignment-json-file #{container_path} \
        --verify 2>&1`

      break if verify_output.include?('completed') && !verify_output.include?('still in progress')

      puts 'Concurrent reassignment in progress, waiting...'
      sleep(5)
    end
  end

  `docker exec kafka1 rm #{container_path} 2>/dev/null`

ensure
  temp_file.close
  temp_file.unlink
end

# Allow metadata to propagate
sleep(5)

# Verify all topics
test_topics.each do |topic|
  topic_info = Karafka::Admin::Topics.info(topic)

  topic_info[:partitions].each do |partition|
    partition_id = partition[:partition_id]
    replica_count = partition[:replica_count] || partition[:replicas]&.size

    assert_equal(
      target_rf,
      replica_count,
      "#{topic} partition #{partition_id} should have RF=#{target_rf}, got #{replica_count}"
    )
  end

  # Verify messages
  messages_after = []
  2.times do |partition|
    partition_messages = Karafka::Admin.read_topic(topic, partition, 100, 0)
    messages_after.concat(partition_messages.map(&:raw_payload))
  end

  original_messages = messages_per_topic[topic]
  original_messages.each do |msg|
    assert(
      messages_after.include?(msg),
      "Message '#{msg}' should be present in #{topic}"
    )
  end

  DT["#{topic}_verified"] = true
end

# Clean up test topics
test_topics.each do |topic|
  begin
    Karafka::Admin.delete_topic(topic)
  rescue StandardError
    # Ignore cleanup errors
  end
end

puts "SUCCESS: Concurrent RF change for #{topic_count} topics completed"
puts "All #{topic_count} topics now have RF=#{target_rf}"
puts 'Data integrity verified for all topics'
