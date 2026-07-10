# frozen_string_literal: true

# An external rdkafka admin instance should serve all admin-based operations without dedicated
# per-operation instances and should stay open and usable afterwards. Consumer-based operations
# on the same admin instance keep working via the dedicated consumers fallback.

setup_karafka

TOPIC = DT.topics[0]

external_admin = Rdkafka::Config.new(
  "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092")
).admin

admin = Karafka::Admin.new(external_client: external_admin)

# Topic management via the external admin
admin.create_topic(TOPIC, 2, 1)

info = admin.topic_info(TOPIC)
assert_equal TOPIC, info[:topic_name]
assert_equal 2, info[:partition_count]

# Cluster metadata via the external admin
assert admin.cluster_info.topics.map { |t| t[:topic_name] }.include?(TOPIC)

admin.create_partitions(TOPIC, 3)
assert_equal 3, admin.topic_info(TOPIC)[:partition_count]

# list_offsets based watermark reads via the external admin
produce_many(TOPIC, DT.uuids(5), partition: 0)

watermarks = admin.read_watermark_offsets({ TOPIC => [0] })
assert_equal [0, 5], watermarks.fetch(TOPIC).fetch(0)

# Consumer-based operations are not capable of running on the external admin and fall back to
# dedicated consumer instances, still fully operational
lags = admin.read_lags_with_offsets({ "nonexisting-group" => [TOPIC] })
assert_equal(
  { offset: -1, lag: -1 },
  lags.fetch("nonexisting-group").fetch(TOPIC).fetch(0)
)

admin.delete_topic(TOPIC)

# The external admin stays fully open and usable afterwards
assert !external_admin.closed?
assert external_admin.metadata.brokers.size >= 1

external_admin.close
