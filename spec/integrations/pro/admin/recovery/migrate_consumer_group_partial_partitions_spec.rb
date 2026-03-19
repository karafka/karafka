# frozen_string_literal: true

# Demonstrates the two-step migration workflow when the source group has committed offsets for
# only some partitions. The target group should receive only those partitions.

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

# Step 1: Read committed offsets via Recovery (bypasses coordinator)
recovered = Karafka::Admin::Recovery.read_committed_offsets(
  SOURCE_GROUP,
  lookback_ms: 60 * 1_000
)

assert_equal 4, recovered[DT.topic][0]
assert_equal 7, recovered[DT.topic][2]
assert !recovered[DT.topic].key?(1), "Partition 1 should not be in recovered offsets"

# Step 2: Write recovered offsets to the target group using standard Admin API
Karafka::Admin::ConsumerGroups.seek(TARGET_GROUP, recovered)

# Verify target group has only the recovered partitions
target_offsets = Karafka::Admin::Recovery.read_committed_offsets(
  TARGET_GROUP,
  lookback_ms: 60 * 1_000
)

assert_equal 4, target_offsets[DT.topic][0]
assert_equal 7, target_offsets[DT.topic][2]
assert !target_offsets[DT.topic].key?(1), "Partition 1 should not be in target group"
