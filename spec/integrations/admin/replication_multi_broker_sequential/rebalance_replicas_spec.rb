# frozen_string_literal: true

# Karafka should rebalance replicas across brokers without changing replication factor

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

test_topic = "it-rebalance-#{SecureRandom.uuid}"
partition_count = 1
initial_rf = 2

begin
  Karafka::Admin.create_topic(test_topic, partition_count, initial_rf)
  sleep(3)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

test_messages = 5.times.map { |i| "rebalance-msg-#{i}-#{SecureRandom.hex(8)}" }
test_messages.each { |msg| produce(test_topic, msg) }

sleep(1)

plan = Karafka::Admin::Replication.rebalance(topic: test_topic)

assert_equal initial_rf, plan.current_replication_factor
assert_equal initial_rf, plan.target_replication_factor
assert_equal partition_count, plan.partitions_assignment.size

plan.partitions_assignment.each do |_partition_id, broker_ids|
  assert_equal initial_rf, broker_ids.size
end

temp_file = Tempfile.new(['rebalance', '.json'])

begin
  plan.export_to_file(temp_file.path)
  File.chmod(0o644, temp_file.path)
  container_path = "/tmp/karafka_rebalance_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`
  `docker exec kafka1 chmod 644 #{container_path} 2>/dev/null`

  `docker exec kafka1 kafka-reassign-partitions \
    --bootstrap-server kafka1:29092 \
    --reassignment-json-file #{container_path} \
    --execute 2>&1`

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

final_topic_info = Karafka::Admin::Topics.info(test_topic)
final_partition = final_topic_info[:partitions].first
final_replica_count = final_partition[:replica_count] || final_partition[:replicas]&.size

assert_equal initial_rf, final_replica_count

messages_after = Karafka::Admin.read_topic(test_topic, 0, 100, 0).map(&:raw_payload)

test_messages.each { |msg| assert messages_after.include?(msg) }

Karafka::Admin.delete_topic(test_topic) rescue nil
