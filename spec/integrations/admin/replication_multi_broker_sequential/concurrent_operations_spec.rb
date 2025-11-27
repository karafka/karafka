# frozen_string_literal: true

# Karafka should handle concurrent RF changes on multiple topics

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

topic_count = 3
test_topics = topic_count.times.map { "it-concurrent-#{SecureRandom.uuid}" }
target_rf = 3

test_topics.each do |topic|
  begin
    Karafka::Admin.create_topic(topic, 1, 1)
  rescue Rdkafka::RdkafkaError => e
    raise unless e.code == :topic_already_exists
  end
end

sleep(2)

messages_per_topic = {}
test_topics.each do |topic|
  messages = 5.times.map { |i| "msg-#{topic}-#{i}-#{SecureRandom.hex(8)}" }
  messages_per_topic[topic] = messages
  messages.each { |msg| produce(topic, msg) }
end

sleep(1)

plans = {}
test_topics.each do |topic|
  plans[topic] = Karafka::Admin.plan_topic_replication(topic: topic, replication_factor: target_rf)
end

all_partitions = []
plans.each do |_topic, plan|
  JSON.parse(plan.reassignment_json)['partitions'].each { |p| all_partitions << p }
end

combined_json = JSON.pretty_generate({ version: 1, partitions: all_partitions })

temp_file = Tempfile.new(['concurrent', '.json'])

begin
  File.write(temp_file.path, combined_json)
  File.chmod(0o644, temp_file.path)
  container_path = "/tmp/karafka_concurrent_#{SecureRandom.hex(4)}.json"
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

test_topics.each do |topic|
  topic_info = Karafka::Admin::Topics.info(topic)

  topic_info[:partitions].each do |partition|
    replica_count = partition[:replica_count] || partition[:replicas]&.size
    assert_equal target_rf, replica_count
  end

  partition_messages = Karafka::Admin.read_topic(topic, 0, 100, 0)
  messages_after = partition_messages.map(&:raw_payload)

  messages_per_topic[topic].each { |msg| assert messages_after.include?(msg) }
end

test_topics.each { |topic| Karafka::Admin.delete_topic(topic) rescue nil }
