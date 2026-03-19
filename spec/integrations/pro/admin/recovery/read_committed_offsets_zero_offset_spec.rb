# frozen_string_literal: true

# When a consumer group has committed offset 0 for a partition, Recovery should return it
# correctly and not treat it as a missing/falsy value.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

produce_many(DT.topic, Array.new(10) { rand.to_s })

# Commit offset 0 explicitly
Karafka::Admin.seek_consumer_group(GROUP_ID, { DT.topic => { 0 => 0 } })

sleep(2)

committed = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_ID,
  lookback_ms: 60 * 1_000
)

assert !committed.empty?, "Expected to find committed offsets"
assert committed[DT.topic].key?(0), "Partition 0 should be present"
assert_equal 0, committed[DT.topic][0]
