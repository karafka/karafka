# frozen_string_literal: true

# When a consumer group commits offsets multiple times, Recovery should return
# the latest committed offset (last write wins).

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

produce_many(DT.topic, Array.new(20) { rand.to_s })

# Commit an initial offset
Karafka::Admin.seek_consumer_group(GROUP_ID, { DT.topic => { 0 => 5 } })
sleep(1)

# Commit a later offset
Karafka::Admin.seek_consumer_group(GROUP_ID, { DT.topic => { 0 => 15 } })
sleep(2)

committed = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_ID,
  lookback_ms: 60 * 1_000
)

assert_equal 15, committed[DT.topic][0]
