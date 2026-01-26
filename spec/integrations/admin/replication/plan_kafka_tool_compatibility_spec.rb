# frozen_string_literal: true

# Karafka-generated JSON should work with kafka-reassign-partitions.sh
#
# This is a TRUE INTEGRATION TEST that validates our JSON is compatible with
# Kafka's official tooling by actually executing kafka-reassign-partitions.sh

require "tempfile"
require "securerandom"

# Skip this spec if Docker is not available or kafka container is not running
# This allows the spec to run on platforms without Docker (e.g., macOS in some CI environments)
docker_available = system("docker --version > /dev/null 2>&1")
kafka_container_running = docker_available && system("docker exec kafka true > /dev/null 2>&1")

unless docker_available && kafka_container_running

  exit 0
end

setup_karafka

class ReplicationKafkaToolConsumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(ReplicationKafkaToolConsumer)

# Create test topic
test_topic = DT.topic

begin
  Karafka::Admin.create_topic(test_topic, 2, 1)
  sleep(0.5)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

# Generate plan (rebalancing keeps same RF, works on single broker)
plan = Karafka::Admin::Replication.rebalance(topic: test_topic)

# Export to file
temp_file = Tempfile.new(["kafka_reassignment", ".json"])

begin
  plan.export_to_file(temp_file.path)

  # Copy JSON to Kafka Docker container
  container_path = "/tmp/karafka_test_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka:#{container_path} 2>&1`

  # Execute kafka-reassign-partitions.sh with our JSON
  kafka_output = %x(docker exec kafka kafka-reassign-partitions \
    --bootstrap-server localhost:9092 \
    --reassignment-json-file #{container_path} \
    --execute 2>&1)

  # Clean up
  `docker exec kafka rm #{container_path} 2>/dev/null`

  # Store results
  DT[:kafka_output] = kafka_output
  DT[:json_content] = File.read(temp_file.path)

  # Validate Kafka accepted the JSON format
  # Even if reassignment fails for business reasons, JSON should be valid
  json_format_valid = !kafka_output.include?("Failed to parse") &&
    !kafka_output.include?("Invalid JSON") &&
    !kafka_output.include?("Unexpected")

  assert(
    json_format_valid,
    "Kafka should accept JSON format. Output: #{kafka_output}"
  )
ensure
  temp_file.close
  temp_file.unlink
end
