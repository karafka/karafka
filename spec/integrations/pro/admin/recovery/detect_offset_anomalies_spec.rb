# frozen_string_literal: true

# When detecting offset anomalies, offsets within the valid watermark range
# should be reported as :ok.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
    config(partitions: 2)
  end
end

GROUP_ID = SecureRandom.uuid

# Produce messages
produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 0)
produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 1)

# Commit offsets within the valid range
Karafka::Admin.seek_consumer_group(
  GROUP_ID,
  { DT.topics[0] => { 0 => 5, 1 => 8 } }
)

sleep(2)

result = Karafka::Admin::Recovery.detect_offset_anomalies(
  GROUP_ID,
  lookback_ms: 60 * 1_000
)

assert !result.empty?, "Expected non-empty anomaly result"

# Both partitions should be :ok since offsets are within valid range
entry0 = result[DT.topics[0]][0]
assert_equal :ok, entry0[:status]
assert_equal 5, entry0[:offset]
assert entry0[:lo_offset] <= 5, "Expected lo_offset <= 5"
assert entry0[:hi_offset] >= 5, "Expected hi_offset >= 5"

entry1 = result[DT.topics[0]][1]
assert_equal :ok, entry1[:status]
assert_equal 8, entry1[:offset]
assert entry1[:lo_offset] <= 8, "Expected lo_offset <= 8"
assert entry1[:hi_offset] >= 8, "Expected hi_offset >= 8"
