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

reassignment_file = Tempfile.new(["validate_cmds_reassignment", ".json"])
topics_to_move_file = Tempfile.new(["validate_cmds_topics", ".json"])

begin
  plan.export_to_file(reassignment_file.path)
  plan.export_topics_to_move_file(topics_to_move_file.path)
  File.chmod(0o644, reassignment_file.path)
  File.chmod(0o644, topics_to_move_file.path)

  reassignment_container_path = "/tmp/karafka_reassignment_#{SecureRandom.hex(4)}.json"
  topics_container_path = "/tmp/karafka_topics_#{SecureRandom.hex(4)}.json"

  cp_reassignment = system("docker cp #{reassignment_file.path} kafka1:#{reassignment_container_path} 2>&1")
  assert cp_reassignment, "Failed to copy reassignment JSON into kafka1 container"

  cp_topics = system("docker cp #{topics_to_move_file.path} kafka1:#{topics_container_path} 2>&1")
  assert cp_topics, "Failed to copy topics-to-move JSON into kafka1 container"

  system("docker exec kafka1 chmod 644 #{reassignment_container_path} 2>/dev/null")
  system("docker exec kafka1 chmod 644 #{topics_container_path} 2>/dev/null")

  error_patterns = [
    "Missing required argument",
    "Failed to parse",
    "Unrecognized option",
    "Exception in thread",
    "not a valid option"
  ]

  plan.execution_commands.each do |phase, command_template|
    command = command_template
      .gsub("<KAFKA_BROKERS>", "kafka1:29092")
      .gsub("reassignment.json", reassignment_container_path)
      .gsub("topics-to-move.json", topics_container_path)
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

  `docker exec kafka1 rm #{reassignment_container_path} 2>/dev/null`
  `docker exec kafka1 rm #{topics_container_path} 2>/dev/null`
ensure
  reassignment_file.close
  reassignment_file.unlink
  topics_to_move_file.close
  topics_to_move_file.unlink
end

begin
  Karafka::Admin.delete_topic(test_topic)
rescue
  nil
end
