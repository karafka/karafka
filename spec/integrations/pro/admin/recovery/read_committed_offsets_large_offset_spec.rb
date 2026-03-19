# frozen_string_literal: true

# When a consumer group has committed very large offsets, Recovery should return them correctly
# without integer overflow or truncation issues.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

produce_many(DT.topic, Array.new(10) { rand.to_s })

# Commit a very large offset that exercises 64-bit integer handling
large_offset = 2_147_483_648 # Just above int32 max (2^31)

Karafka::Admin.seek_consumer_group(GROUP_ID, { DT.topic => { 0 => large_offset } })

sleep(2)

committed = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_ID,
  lookback_ms: 60 * 1_000
)

assert !committed.empty?, "Expected to find committed offsets"
assert_equal large_offset, committed[DT.topic][0]
