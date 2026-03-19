# frozen_string_literal: true

# Demonstrates the two-step consumer group migration workflow using Recovery to read offsets
# and ConsumerGroups.seek to write them to the target group.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
    config(partitions: 2)
  end

  topic DT.topics[1] do
    active false
  end
end

SOURCE_GROUP = SecureRandom.uuid
TARGET_GROUP = SecureRandom.uuid

produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 0)
produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 1)
produce_many(DT.topics[1], Array.new(10) { rand.to_s })

# Commit offsets for the source group
Karafka::Admin.seek_consumer_group(
  SOURCE_GROUP,
  {
    DT.topics[0] => { 0 => 7, 1 => 3 },
    DT.topics[1] => { 0 => 9 }
  }
)

sleep(2)

# Step 1: Read committed offsets from the broken group via Recovery (bypasses coordinator)
recovered = Karafka::Admin::Recovery.read_committed_offsets(
  SOURCE_GROUP,
  lookback_ms: 60 * 1_000
)

assert !recovered.empty?, "Expected recovered offsets"
assert_equal 7, recovered[DT.topics[0]][0]
assert_equal 3, recovered[DT.topics[0]][1]
assert_equal 9, recovered[DT.topics[1]][0]

# Step 2: Write recovered offsets to the target group using standard Admin API
Karafka::Admin::ConsumerGroups.seek(TARGET_GROUP, recovered)

# Verify the target group actually has the offsets via the normal Admin API
lags = Karafka::Admin.read_lags_with_offsets(
  { TARGET_GROUP => [DT.topics[0], DT.topics[1]] }
)

assert_equal 7, lags[TARGET_GROUP][DT.topics[0]][0][:offset]
assert_equal 3, lags[TARGET_GROUP][DT.topics[0]][1][:offset]
assert_equal 9, lags[TARGET_GROUP][DT.topics[1]][0][:offset]
