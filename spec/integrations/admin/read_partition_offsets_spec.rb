# frozen_string_literal: true

# This integration spec exercises the Admin#read_partition_offsets API for querying partition
# offsets without a consumer group, using the Kafka ListOffsets admin operation.

setup_karafka

topic = DT.topics[0]

Karafka::Admin.create_topic(topic, 2, 1)

# Produce some messages so watermarks are non-trivial
5.times { |i| PRODUCERS.regular.produce_sync(topic: topic, payload: i.to_s, partition: 0) }
3.times { |i| PRODUCERS.regular.produce_sync(topic: topic, payload: i.to_s, partition: 1) }

# --- :earliest ---
earliest_results = Karafka::Admin.read_partition_offsets(
  { topic => [
    { partition: 0, offset: :earliest },
    { partition: 1, offset: :earliest }
  ] }
)

assert_equal 2, earliest_results.size
assert earliest_results.all? { |r| r[:topic] == topic }
assert_equal 0, earliest_results.find { |r| r[:partition] == 0 }[:offset]
assert_equal 0, earliest_results.find { |r| r[:partition] == 1 }[:offset]

# --- :latest ---
latest_results = Karafka::Admin.read_partition_offsets(
  { topic => [
    { partition: 0, offset: :latest },
    { partition: 1, offset: :latest }
  ] }
)

assert_equal 2, latest_results.size
assert_equal 5, latest_results.find { |r| r[:partition] == 0 }[:offset]
assert_equal 3, latest_results.find { |r| r[:partition] == 1 }[:offset]

# --- result shape ---
sample = earliest_results.first
assert sample.key?(:topic)
assert sample.key?(:partition)
assert sample.key?(:offset)
assert sample.key?(:timestamp)
assert sample.key?(:leader_epoch)

# --- isolation_level keyword is accepted ---
committed_results = Karafka::Admin.read_partition_offsets(
  { topic => [{ partition: 0, offset: :latest }] },
  isolation_level: Karafka::Admin::IsolationLevels::READ_COMMITTED
)

assert_equal 1, committed_results.size
assert_equal 5, committed_results.first[:offset]

# --- instance-level API works too ---
admin = Karafka::Admin.new
instance_results = admin.read_partition_offsets({ topic => [{ partition: 0, offset: :earliest }] })
assert_equal 1, instance_results.size
assert_equal 0, instance_results.first[:offset]
