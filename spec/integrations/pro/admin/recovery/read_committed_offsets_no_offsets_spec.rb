# frozen_string_literal: true

# When a consumer group has never committed any offsets, Recovery should return
# an empty hash.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

committed = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_ID,
  lookback_ms: 60 * 1_000
)

assert_equal({}, committed)
