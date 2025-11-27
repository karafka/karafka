# frozen_string_literal: true

# Karafka should have valid ISR after replication factor change

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
broker_count = cluster_info.brokers.size

exit 0 unless broker_count >= 3

test_topic = "it-isr-test-#{SecureRandom.uuid}"
target_rf = 3

begin
  Karafka::Admin.create_topic(test_topic, 1, 1)
  sleep(3)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

plan = Karafka::Admin.plan_topic_replication(
  topic: test_topic,
  replication_factor: target_rf
)

temp_file = Tempfile.new(['isr_test', '.json'])

begin
  plan.export_to_file(temp_file.path)
  File.chmod(0o644, temp_file.path)
  container_path = "/tmp/karafka_isr_#{SecureRandom.hex(4)}.json"
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

sleep(5)

final_topic_info = Karafka::Admin::Topics.info(test_topic)

final_topic_info[:partitions].each do |partition|
  partition_id = partition[:partition_id]

  replica_count = partition[:replica_count] || partition[:replicas]&.size
  assert_equal target_rf, replica_count

  isr = partition[:in_sync_replicas] || partition[:in_sync_replica_brokers] || partition[:isr] || []
  isr_list = if isr.is_a?(Array) && isr.first.respond_to?(:node_id)
               isr.map(&:node_id)
             elsif isr.is_a?(Array)
               isr
             else
               [isr].compact
             end

  assert isr_list.size >= 1

  leader = partition[:leader] || partition[:leader_id]
  leader_id = leader.respond_to?(:node_id) ? leader.node_id : leader

  assert !leader_id.nil? && leader_id >= 0
end

test_msg = "isr-test-#{SecureRandom.hex(8)}"
produce(test_topic, test_msg, partition: 0)
sleep(1)

messages = Karafka::Admin.read_topic(test_topic, 0, 100, 0)
assert messages.any? { |m| m.raw_payload == test_msg }

Karafka::Admin.delete_topic(test_topic) rescue nil
