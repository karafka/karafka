# frozen_string_literal: true

# When a consumer group has committed offsets for only some partitions of a multi-partition topic,
# Recovery should return only the partitions that have committed offsets and not include others.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
    config(partitions: 4)
  end
end

GROUP_ID = SecureRandom.uuid

produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 0)
produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 1)
produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 2)
produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 3)

# Only commit offsets for partitions 1 and 3, skipping 0 and 2
Karafka::Admin.seek_consumer_group(
  GROUP_ID,
  { DT.topic => { 1 => 5, 3 => 8 } }
)

sleep(2)

committed = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_ID,
  lookback_ms: 60 * 1_000
)

assert !committed.empty?, "Expected to find committed offsets"

# Partitions that were committed should be present with correct values
assert_equal 5, committed[DT.topic][1]
assert_equal 8, committed[DT.topic][3]

# Partitions that were NOT committed should be absent
assert !committed[DT.topic].key?(0), "Partition 0 should not be present"
assert !committed[DT.topic].key?(2), "Partition 2 should not be present"
