# frozen_string_literal: true

# Karafka::Admin.create_topic with validate_only should only ask the broker to validate the
# request: a valid one should create no topic and an invalid one should raise. A topic config
# given without braces should keep working.

setup_karafka

Karafka::Admin.create_topic(
  DT.topic,
  2,
  1,
  validate_only: true,
  operation_timeout_ms: 10_000,
  request_timeout_ms: 15_000
)

assert !Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] }.include?(DT.topic)

invalid_config_error = nil

begin
  Karafka::Admin.create_topic(DT.topic, 1, 1, { "cleanup.policy" => "na" }, validate_only: true)
rescue Rdkafka::RdkafkaError => e
  invalid_config_error = e
end

assert_equal :invalid_config, invalid_config_error.code

Karafka::Admin.create_topic(DT.topic, 1, 1, "cleanup.policy" => "compact")

cleanup_policy = Karafka::Admin::Configs
  .describe(Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topic))
  .first
  .configs
  .find { |config| config.name == "cleanup.policy" }
  .value

assert_equal "compact", cleanup_policy

existing_topic_error = nil

begin
  Karafka::Admin.create_topic(DT.topic, 1, 1, validate_only: true)
rescue Rdkafka::RdkafkaError => e
  existing_topic_error = e
end

assert_equal :topic_already_exists, existing_topic_error.code
