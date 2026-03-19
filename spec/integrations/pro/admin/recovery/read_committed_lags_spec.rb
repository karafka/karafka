# frozen_string_literal: true

# When reading committed lags, we should get offset, lag, and high watermark
# for each partition that has committed offsets.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
    config(partitions: 2)
  end
end

GROUP_ID = SecureRandom.uuid

# Produce messages so topics have data and watermarks
produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 0)
produce_many(DT.topics[0], Array.new(20) { rand.to_s }, partition: 1)

# Commit offsets partway through
Karafka::Admin.seek_consumer_group(
  GROUP_ID,
  { DT.topics[0] => { 0 => 5, 1 => 10 } }
)

sleep(2)

result = Karafka::Admin::Recovery.read_committed_lags(
  GROUP_ID,
  lookback_ms: 60 * 1_000
)

assert !result.empty?, "Expected non-empty lags result"

# Partition 0: offset 5, 10 messages produced => hi_offset 10, lag 5
entry0 = result[DT.topics[0]][0]
assert_equal 5, entry0[:offset]
assert_equal 10, entry0[:hi_offset]
assert_equal 5, entry0[:lag]

# Partition 1: offset 10, 20 messages produced => hi_offset 20, lag 10
entry1 = result[DT.topics[0]][1]
assert_equal 10, entry1[:offset]
assert_equal 20, entry1[:hi_offset]
assert_equal 10, entry1[:lag]
