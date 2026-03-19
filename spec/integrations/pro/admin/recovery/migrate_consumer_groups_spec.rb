# frozen_string_literal: true

# When batch-migrating multiple consumer groups, all targets should end up
# with the same offsets as their respective sources.

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

SOURCE1 = SecureRandom.uuid
SOURCE2 = SecureRandom.uuid
TARGET1 = SecureRandom.uuid
TARGET2 = SecureRandom.uuid

produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 0)
produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 1)
produce_many(DT.topics[1], Array.new(10) { rand.to_s })

# Commit offsets for both source groups
Karafka::Admin.seek_consumer_group(
  SOURCE1,
  { DT.topics[0] => { 0 => 5, 1 => 8 } }
)

Karafka::Admin.seek_consumer_group(
  SOURCE2,
  { DT.topics[1] => { 0 => 3 } }
)

sleep(2)

# Batch migrate
migrated = Karafka::Admin::Recovery.migrate_consumer_groups(
  { SOURCE1 => TARGET1, SOURCE2 => TARGET2 },
  lookback_ms: 60 * 1_000
)

# Verify returned offsets
assert_equal 5, migrated[SOURCE1][DT.topics[0]][0]
assert_equal 8, migrated[SOURCE1][DT.topics[0]][1]
assert_equal 3, migrated[SOURCE2][DT.topics[1]][0]

# Verify targets actually have the offsets
lags1 = Karafka::Admin.read_lags_with_offsets(
  { TARGET1 => [DT.topics[0]] }
)
assert_equal 5, lags1[TARGET1][DT.topics[0]][0][:offset]
assert_equal 8, lags1[TARGET1][DT.topics[0]][1][:offset]

lags2 = Karafka::Admin.read_lags_with_offsets(
  { TARGET2 => [DT.topics[1]] }
)
assert_equal 3, lags2[TARGET2][DT.topics[1]][0][:offset]
