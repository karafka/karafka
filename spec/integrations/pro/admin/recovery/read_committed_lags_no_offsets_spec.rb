# frozen_string_literal: true

# When reading committed lags for a group with no committed offsets,
# we should get an empty result.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

result = Karafka::Admin::Recovery.read_committed_lags(
  GROUP_ID,
  lookback_ms: 60 * 1_000
)

assert result.empty?, "Expected empty result for group with no offsets, got: #{result}"
