# frozen_string_literal: true

# When migrating a consumer group that has committed offsets for only some partitions of a
# multi-partition topic, the target group should receive only those partitions and not others.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
    config(partitions: 3)
  end
end

SOURCE_GROUP = SecureRandom.uuid
TARGET_GROUP = SecureRandom.uuid

produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 0)
produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 1)
produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 2)

# Source group only has offsets for partitions 0 and 2, not 1
Karafka::Admin.seek_consumer_group(
  SOURCE_GROUP,
  { DT.topic => { 0 => 4, 2 => 7 } }
)

sleep(2)

migrated = Karafka::Admin::Recovery.migrate_consumer_group(
  SOURCE_GROUP,
  TARGET_GROUP,
  lookback_ms: 60 * 1_000
)

assert_equal 4, migrated[DT.topic][0]
assert_equal 7, migrated[DT.topic][2]
assert !migrated[DT.topic].key?(1), "Partition 1 should not be in migrated offsets"

# Verify target group has only the migrated partitions
target_offsets = Karafka::Admin::Recovery.read_committed_offsets(
  TARGET_GROUP,
  lookback_ms: 60 * 1_000
)

assert_equal 4, target_offsets[DT.topic][0]
assert_equal 7, target_offsets[DT.topic][2]
assert !target_offsets[DT.topic].key?(1), "Partition 1 should not be in target group"
