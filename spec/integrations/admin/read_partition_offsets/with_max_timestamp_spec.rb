# frozen_string_literal: true

# `:max_timestamp` must return the offset of the message with the HIGHEST timestamp, which is not
# necessarily the last message in the partition. Producing with explicit out-of-order `CreateTime`
# timestamps is the only way to tell it apart from `:latest`: when messages happen to be produced
# in timestamp order the two agree, so a regression collapsing `:max_timestamp` into `:latest`
# would pass unnoticed on any ordinary topic.
#
# This is also one of the two modes where the returned `:timestamp` carries a real value. It comes
# back `-1` for `:earliest`/`:latest`, so asserting it here pins the one place it is meaningful.

setup_karafka

topic = DT.topic

Karafka::Admin.create_topic(topic, 1, 1)

# Far enough in the past to be unambiguous, while staying well inside any broker-side accepted
# timestamp window
base = (Time.now.to_f * 1000).to_i - 600_000

# The highest timestamp (base + 30s) deliberately sits at offset 2, while the last message is at
# offset 4 and the end offset is 5
deltas = [0, 10_000, 30_000, 20_000, 25_000]

deltas.each_with_index do |delta, index|
  produce(topic, index.to_s, partition: 0, timestamp: base + delta)
end

max_timestamp = Karafka::Admin.read_partition_offsets(
  { topic => [{ partition: 0, offset: :max_timestamp }] }
).first

assert_equal 2, max_timestamp[:offset]
assert_equal base + 30_000, max_timestamp[:timestamp]

latest = Karafka::Admin.read_partition_offsets(
  { topic => [{ partition: 0, offset: :latest }] }
).first

# `:latest` is the end offset and reports no timestamp at all
assert_equal 5, latest[:offset]
assert_equal(-1, latest[:timestamp])

# The whole point of the out-of-order setup: `:max_timestamp` must match neither the end offset
# nor the last message offset, otherwise this spec would also pass on an implementation that
# silently treated `:max_timestamp` as `:latest`
assert max_timestamp[:offset] != latest[:offset]
assert max_timestamp[:offset] != deltas.size - 1
