# frozen_string_literal: true

# When verifying a migration, matching offsets should report :ok status
# and mismatched offsets should report :mismatch with details.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
    config(partitions: 2)
  end
end

SOURCE_GROUP = SecureRandom.uuid
TARGET_GROUP = SecureRandom.uuid

produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 0)
produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 1)

# Commit offsets for source
Karafka::Admin.seek_consumer_group(
  SOURCE_GROUP,
  { DT.topics[0] => { 0 => 5, 1 => 8 } }
)

sleep(2)

# Migrate source to target
Karafka::Admin::Recovery.migrate_consumer_group(
  SOURCE_GROUP,
  TARGET_GROUP,
  lookback_ms: 60 * 1_000
)

sleep(2)

# Verify migration
result = Karafka::Admin::Recovery.verify_migration(
  SOURCE_GROUP,
  TARGET_GROUP,
  lookback_ms: 60 * 1_000
)

assert_equal :ok, result[:status]
assert result[:mismatches].empty?, "Expected no mismatches after migration"
assert_equal 5, result[:source_offsets][DT.topics[0]][0]
assert_equal 8, result[:source_offsets][DT.topics[0]][1]
assert_equal 5, result[:target_offsets][DT.topics[0]][0]
assert_equal 8, result[:target_offsets][DT.topics[0]][1]
