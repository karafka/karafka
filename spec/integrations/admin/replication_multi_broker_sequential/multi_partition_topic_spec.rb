# frozen_string_literal: true

# Karafka should increase replication factor for multi-partition topics

docker_available = system('docker --version > /dev/null 2>&1')
kafka_container_running = docker_available && system('docker exec kafka1 true > /dev/null 2>&1')

exit 0 unless docker_available && kafka_container_running

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(Consumer)

cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

exit 0 unless broker_count >= 3

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

messages_by_partition = {}
partition_count.times do |partition|
  messages_by_partition[partition] = []
  3.times do |i|
    msg = "partition-#{partition}-msg-#{i}-#{SecureRandom.hex(4)}"
    messages_by_partition[partition] << msg
    produce(test_topic, msg, partition: partition)
  end
end

sleep(2)

initial_info = Karafka::Admin::Topics.info(test_topic)

assert_equal partition_count, initial_info[:partitions].size

initial_info[:partitions].each do |partition|
  replica_count = partition[:replica_count] || partition[:replicas]&.size
  assert_equal initial_rf, replica_count
end

plan = Karafka::Admin.plan_topic_replication(
  topic: test_topic,
  replication_factor: target_rf
)

assert_equal partition_count, plan.partitions_assignment.size

plan.partitions_assignment.each do |_partition_id, broker_ids|
  assert_equal target_rf, broker_ids.size
  assert_equal broker_ids.uniq.size, broker_ids.size
end

temp_file = Tempfile.new(['multi_partition', '.json'])

begin
  plan.export_to_file(temp_file.path)
  File.chmod(0o644, temp_file.path)
  container_path = "/tmp/karafka_multi_part_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`
  `docker exec kafka1 chmod 644 #{container_path} 2>/dev/null`

  `docker exec kafka1 kafka-reassign-partitions \
    --bootstrap-server kafka1:29092 \
    --reassignment-json-file #{container_path} \
    --execute 2>&1`

  Timeout.timeout(300) do
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

sleep(5)

final_info = Karafka::Admin::Topics.info(test_topic)

final_info[:partitions].each do |partition|
  replica_count = partition[:replica_count] || partition[:replicas]&.size
  assert_equal target_rf, replica_count
end

partition_count.times do |partition|
  partition_messages = Karafka::Admin.read_topic(test_topic, partition, 100, 0)
  partition_payloads = partition_messages.map(&:raw_payload)

  messages_by_partition[partition].each { |msg| assert partition_payloads.include?(msg) }
end

begin
  Karafka::Admin.delete_topic(test_topic)
rescue StandardError
  nil
end
