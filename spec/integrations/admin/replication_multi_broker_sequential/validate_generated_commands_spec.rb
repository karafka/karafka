# frozen_string_literal: true

# Karafka should generate valid kafka-reassign-partitions commands that actually work
# against a real Kafka cluster. This validates that plan.execution_commands produces
# commands accepted by the Kafka tooling without argument errors.

docker_available = system("docker --version > /dev/null 2>&1")
kafka_container_running = docker_available && system("docker exec kafka1 true > /dev/null 2>&1")

exit 0 unless docker_available && kafka_container_running

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(Consumer)

cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

exit 0 unless broker_count >= 3

test_topic = "it-validate-cmds-#{SecureRandom.uuid}"
initial_rf = 1
target_rf = 3

begin
  Karafka::Admin.create_topic(test_topic, 1, initial_rf)
  sleep(3)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

plan = Karafka::Admin.plan_topic_replication(topic: test_topic, replication_factor: target_rf)

temp_file = Tempfile.new(["validate_cmds", ".json"])

begin
  plan.export_to_file(temp_file.path)
  File.chmod(0o644, temp_file.path)

  container_path = "/tmp/karafka_validate_cmds_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`
  `docker exec kafka1 chmod 644 #{container_path} 2>/dev/null`

  error_patterns = [
    "Missing required argument",
    "Invalid",
    "Failed to parse",
    "Unrecognized option",
    "Exception in thread",
    "not a valid option"
  ]

  plan.execution_commands.each do |phase, command_template|
    command = command_template
      .gsub("<KAFKA_BROKERS>", "kafka1:29092")
      .gsub("reassignment.json", container_path)
      .gsub("kafka-reassign-partitions.sh", "kafka-reassign-partitions")

    output = %x(docker exec kafka1 #{command} 2>&1)

    has_error = error_patterns.any? { |pattern| output.include?(pattern) }

    assert(
      !has_error,
      "Command for :#{phase} phase produced an error.\n" \
      "Command: #{command}\n" \
      "Output: #{output}"
    )
  end

  `docker exec kafka1 rm #{container_path} 2>/dev/null`
ensure
  temp_file.close
  temp_file.unlink
end

begin
  Karafka::Admin.delete_topic(test_topic)
rescue
  nil
end
