# frozen_string_literal: true

# Karafka should respect manual broker assignment when increasing replication factor

require 'tempfile'
require 'securerandom'
require 'timeout'

docker_available = system('docker --version > /dev/null 2>&1')
kafka_container_running = docker_available && system('docker exec kafka1 true > /dev/null 2>&1')

exit 0 unless docker_available && kafka_container_running

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(Consumer)

cluster_info = Karafka::Admin.cluster_info
brokers = cluster_info.brokers
broker_count = brokers.size

exit 0 unless broker_count >= 3

broker_ids = brokers.map do |broker|
  broker.is_a?(Hash) ? (broker[:broker_id] || broker[:node_id]) : broker.node_id
end.sort

test_topic = "it-manual-assign-#{SecureRandom.uuid}"

begin
  Karafka::Admin.create_topic(test_topic, 1, 1)
  sleep(3)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

test_msg = "manual-assign-#{SecureRandom.hex(8)}"
produce(test_topic, test_msg)
sleep(1)

target_brokers = broker_ids.first(3)
manual_assignment = { 0 => target_brokers }

plan = Karafka::Admin.plan_topic_replication(
  topic: test_topic,
  replication_factor: 3,
  brokers: manual_assignment
)

assert_equal manual_assignment, plan.partitions_assignment

json_data = JSON.parse(plan.reassignment_json)
partition_data = json_data['partitions'].first

assert_equal target_brokers.sort, partition_data['replicas'].sort

temp_file = Tempfile.new(['manual_assign', '.json'])

begin
  plan.export_to_file(temp_file.path)
  File.chmod(0o644, temp_file.path)
  container_path = "/tmp/karafka_manual_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`
  `docker exec kafka1 chmod 644 #{container_path} 2>/dev/null`

  `docker exec kafka1 kafka-reassign-partitions \
    --bootstrap-server kafka1:29092 \
    --reassignment-json-file #{container_path} \
    --execute 2>&1`

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

final_info = Karafka::Admin::Topics.info(test_topic)
final_partition = final_info[:partitions].first
final_replica_count = final_partition[:replica_count] || final_partition[:replicas]&.size

assert_equal target_brokers.size, final_replica_count

messages = Karafka::Admin.read_topic(test_topic, 0, 100, 0)
assert messages.any? { |m| m.raw_payload == test_msg }

Karafka::Admin.delete_topic(test_topic) rescue nil
