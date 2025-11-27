# frozen_string_literal: true

# Karafka should raise errors for invalid replication factor values

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

test_topic = DT.topic

begin
  Karafka::Admin.create_topic(test_topic, 2, 1)
  sleep(1)
rescue Rdkafka::RdkafkaError => e
  raise unless e.code == :topic_already_exists
end

# Test: RF higher than broker count
invalid_rf = broker_count + 5
error_raised = false
error_message = nil

begin
  Karafka::Admin.plan_topic_replication(topic: test_topic, replication_factor: invalid_rf)
rescue Karafka::Errors::InvalidConfigurationError => e
  error_raised = true
  error_message = e.message
end

assert error_raised
assert error_message.include?('broker') || error_message.include?('exceed')

# Test: RF equal to current
current_topic_info = Karafka::Admin::Topics.info(test_topic)
current_rf = current_topic_info[:partitions].first[:replica_count] ||
             current_topic_info[:partitions].first[:replicas]&.size

error_raised_same_rf = false

begin
  Karafka::Admin.plan_topic_replication(topic: test_topic, replication_factor: current_rf)
rescue Karafka::Errors::InvalidConfigurationError
  error_raised_same_rf = true
end

assert error_raised_same_rf

# Test: RF less than 1
error_raised_lower_rf = false

begin
  Karafka::Admin.plan_topic_replication(topic: test_topic, replication_factor: 0)
rescue Karafka::Errors::InvalidConfigurationError
  error_raised_lower_rf = true
end

assert error_raised_lower_rf

# Test: Valid RF should work
valid_plan_created = false

begin
  plan = Karafka::Admin.plan_topic_replication(
    topic: test_topic,
    replication_factor: [broker_count, 3].min
  )
  valid_plan_created = !plan.nil?
rescue Karafka::Errors::InvalidConfigurationError
  valid_plan_created = false
end

assert valid_plan_created
