# frozen_string_literal: true

# When reading committed offsets with a very short lookback window, commits that happened before
# the window should not be returned. This verifies the lookback_ms parameter works correctly.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

produce_many(DT.topic, Array.new(10) { rand.to_s })

# Commit offsets
Karafka::Admin.seek_consumer_group(GROUP_ID, { DT.topic => { 0 => 5 } })

# Wait long enough for the commit to be well in the past
sleep(5)

# Read with a 1ms lookback window - the commit happened ~5 seconds ago so it should be missed
committed = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_ID,
  lookback_ms: 1
)

assert_equal({}, committed)
