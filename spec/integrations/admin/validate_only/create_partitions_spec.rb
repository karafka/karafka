# frozen_string_literal: true

# Karafka::Admin.create_partitions with validate_only should only ask the broker to validate the
# request: a valid one should add no partitions and an invalid one should raise.

setup_karafka

Karafka::Admin.create_topic(DT.topic, 2, 1)

Karafka::Admin.create_partitions(
  DT.topic,
  5,
  validate_only: true,
  operation_timeout_ms: 10_000,
  request_timeout_ms: 15_000
)

assert_equal 2, Karafka::Admin.topic_info(DT.topic).fetch(:partition_count)

downscale_error = nil

begin
  Karafka::Admin.create_partitions(DT.topic, 1, validate_only: true)
rescue Rdkafka::RdkafkaError => e
  downscale_error = e
end

assert_equal :invalid_partitions, downscale_error.code

Karafka::Admin.create_partitions(DT.topic, 5, operation_timeout_ms: 10_000)

assert_equal 5, Karafka::Admin.topic_info(DT.topic).fetch(:partition_count)
