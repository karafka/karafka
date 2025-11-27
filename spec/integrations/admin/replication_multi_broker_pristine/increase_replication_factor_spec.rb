# frozen_string_literal: true

# Karafka should increase topic replication factor from 1 to 3 using kafka-reassign-partitions

require 'tempfile'
require 'securerandom'
require 'timeout'

docker_available = system('docker --version > /dev/null 2>&1')
kafka_container_running = docker_available && system('docker exec kafka1 true > /dev/null 2>&1')

unless docker_available && kafka_container_running
  exit 0
end

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(Consumer)

cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size

exit 0 unless broker_count >= 3

test_topic = "it-rf-increase-#{SecureRandom.uuid}"
initial_rf = 1
target_rf = 3

begin
  Karafka::Admin.create_topic(test_topic, 1, initial_rf)
  sleep(3)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

test_messages = 10.times.map { |i| "message-#{i}-#{SecureRandom.hex(8)}" }
test_messages.each { |msg| produce(test_topic, msg) }
sleep(1)

initial_topic_info = Karafka::Admin::Topics.info(test_topic)
initial_partition = initial_topic_info[:partitions].first
actual_initial_rf = initial_partition[:replica_count] || initial_partition[:replicas]&.size

assert_equal initial_rf, actual_initial_rf

messages_before = Karafka::Admin.read_topic(test_topic, 0, 100, 0).map(&:raw_payload)
assert_equal test_messages.size, messages_before.size

plan = Karafka::Admin.plan_topic_replication(topic: test_topic, replication_factor: target_rf)

assert_equal test_topic, plan.topic
assert_equal initial_rf, plan.current_replication_factor
assert_equal target_rf, plan.target_replication_factor

plan.partitions_assignment.each do |partition_id, broker_ids|
  assert_equal target_rf, broker_ids.size
  assert_equal broker_ids.uniq.size, broker_ids.size
end

temp_file = Tempfile.new(['rf_increase', '.json'])

begin
  plan.export_to_file(temp_file.path)
  File.chmod(0o644, temp_file.path)

  container_path = "/tmp/karafka_rf_increase_#{SecureRandom.hex(4)}.json"
  `docker cp #{temp_file.path} kafka1:#{container_path} 2>&1`
  `docker exec kafka1 chmod 644 #{container_path} 2>/dev/null`

  execute_output = `docker exec kafka1 kafka-reassign-partitions \
    --bootstrap-server kafka1:29092 \
    --reassignment-json-file #{container_path} \
    --execute 2>&1`

  assert(
    execute_output.include?('Successfully started') ||
    execute_output.include?('Current partition replica assignment')
  )

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

final_topic_info = Karafka::Admin::Topics.info(test_topic)
final_topic_info[:partitions].each do |partition|
  replica_count = partition[:replica_count] || partition[:replicas]&.size
  assert_equal target_rf, replica_count
end

messages_after = Karafka::Admin.read_topic(test_topic, 0, 100, 0).map(&:raw_payload)
assert_equal messages_before.size, messages_after.size
test_messages.each { |msg| assert messages_after.include?(msg) }

new_message = "post-rf-change-#{SecureRandom.hex(8)}"
produce(test_topic, new_message)
sleep(1)

post_messages = Karafka::Admin.read_topic(test_topic, 0, 100, 0)
assert post_messages.any? { |m| m.raw_payload == new_message }

Karafka::Admin.delete_topic(test_topic) rescue nil
