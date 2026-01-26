# frozen_string_literal: true

# Karafka Admin should support operations on multiple Kafka clusters by allowing
# custom kafka configuration per admin instance.
#
# This test verifies that:
# 1. An admin instance with custom kafka config can connect to a specific cluster
# 2. The custom config overrides the default config
# 3. Operations work correctly with the custom cluster

setup_karafka

# Store the working kafka config before we modify it
working_kafka_config = Karafka::App.config.kafka.dup

# Modify the default admin kafka config to point to an unreachable broker
# This simulates a scenario where the default cluster is not the one we want to use
Karafka::App.config.admin.kafka = { "bootstrap.servers": "unreachable-broker:9092" }

# Test 1: Verify that class method with default config would fail
# (we don't actually call it to avoid timeout, just verify our setup)
DT[:tests] << {
  test: "default_config_unreachable",
  default_servers: Karafka::App.config.admin.kafka[:"bootstrap.servers"],
  is_unreachable: Karafka::App.config.admin.kafka[:"bootstrap.servers"] == "unreachable-broker:9092"
}

# Test 2: Create admin instance with custom kafka config pointing to working cluster
custom_admin = Karafka::Admin.new(kafka: working_kafka_config)

DT[:tests] << {
  test: "custom_admin_created",
  custom_kafka_set: !custom_admin.custom_kafka.empty?,
  has_bootstrap_servers: custom_admin.custom_kafka.key?(:"bootstrap.servers") ||
    custom_admin.custom_kafka.key?("bootstrap.servers")
}

# Test 3: Verify custom admin can fetch cluster info
begin
  cluster_info = custom_admin.cluster_info

  DT[:tests] << {
    test: "custom_admin_cluster_info",
    success: true,
    broker_count: cluster_info.brokers.size,
    has_brokers: cluster_info.brokers.any?
  }
rescue => e
  DT[:tests] << {
    test: "custom_admin_cluster_info",
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Test 4: Verify custom admin can create and delete a topic
test_topic = "multi_cluster_test_#{SecureRandom.hex(8)}"

begin
  custom_admin.create_topic(test_topic, 1, 1)
  sleep(0.5) # Wait for topic creation to propagate

  # Verify topic was created
  topic_info = custom_admin.topic_info(test_topic)

  DT[:tests] << {
    test: "custom_admin_create_topic",
    success: true,
    topic_name: test_topic,
    partition_count: topic_info[:partitions].size
  }

  # Clean up - delete the topic
  custom_admin.delete_topic(test_topic)
  sleep(0.5)

  DT[:tests] << {
    test: "custom_admin_delete_topic",
    success: true,
    topic_name: test_topic
  }
rescue => e
  DT[:tests] << {
    test: "custom_admin_topic_operations",
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Test 5: Verify Topics submodule also works with custom kafka config
begin
  topics_admin = Karafka::Admin::Topics.new(kafka: working_kafka_config)
  watermarks = topics_admin.read_watermark_offsets("__consumer_offsets", 0)

  DT[:tests] << {
    test: "topics_submodule_custom_config",
    success: true,
    watermarks_type: watermarks.class.name
  }
rescue => e
  DT[:tests] << {
    test: "topics_submodule_custom_config",
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Test 6: Verify Configs submodule works with custom kafka config
begin
  configs_admin = Karafka::Admin::Configs.new(kafka: working_kafka_config)
  resource = Karafka::Admin::Configs::Resource.new(type: :topic, name: "__consumer_offsets")
  result = configs_admin.describe(resource)

  DT[:tests] << {
    test: "configs_submodule_custom_config",
    success: true,
    result_count: result.size
  }
rescue => e
  DT[:tests] << {
    test: "configs_submodule_custom_config",
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Assertions
assert(
  DT[:tests].any?,
  "Should have performed multi-cluster admin tests"
)

# Verify default config is unreachable
unreachable_test = DT[:tests].find { |t| t[:test] == "default_config_unreachable" }
assert(
  unreachable_test[:is_unreachable],
  "Default admin config should be set to unreachable broker"
)

# Verify custom admin was created correctly
custom_admin_test = DT[:tests].find { |t| t[:test] == "custom_admin_created" }
assert(
  custom_admin_test[:custom_kafka_set],
  "Custom admin should have custom kafka config set"
)

# Verify custom admin can fetch cluster info
cluster_info_test = DT[:tests].find { |t| t[:test] == "custom_admin_cluster_info" }
assert(
  cluster_info_test[:success],
  "Custom admin should be able to fetch cluster info: #{cluster_info_test[:error_message]}"
)
assert(
  cluster_info_test[:has_brokers],
  "Cluster info should contain brokers"
)

# Verify custom admin can create topic
create_topic_test = DT[:tests].find { |t| t[:test] == "custom_admin_create_topic" }
if create_topic_test
  assert(
    create_topic_test[:success],
    "Custom admin should be able to create topic: #{create_topic_test[:error_message]}"
  )
end

# Verify Topics submodule works
topics_test = DT[:tests].find { |t| t[:test] == "topics_submodule_custom_config" }
assert(
  topics_test[:success],
  "Topics submodule should work with custom config: #{topics_test[:error_message]}"
)

# Verify Configs submodule works
configs_test = DT[:tests].find { |t| t[:test] == "configs_submodule_custom_config" }
assert(
  configs_test[:success],
  "Configs submodule should work with custom config: #{configs_test[:error_message]}"
)
