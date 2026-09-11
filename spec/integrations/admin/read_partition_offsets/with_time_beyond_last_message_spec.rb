# frozen_string_literal: true

# When an Integer timestamp is beyond the timestamp of the last message, there is no "first offset
# at or after" it to return. Kafka answers with `-1` and no leader epoch, and that sentinel must
# reach the caller untouched: silently substituting the end offset would make tooling built on this
# API (lag, time-travel debugging) treat "nothing matched" as "caught up to the newest message".
#
# This mirrors the boundary already pinned for the sibling read API in
# `spec/integrations/admin/read_topic/with_time_beyond_last_message_spec.rb`.

setup_karafka

topic = DT.topic

Karafka::Admin.create_topic(topic, 1, 1)

base = (Time.now.to_f * 1000).to_i - 600_000

deltas = [0, 10_000, 20_000, 30_000]

deltas.each_with_index do |delta, index|
  produce(topic, index.to_s, partition: 0, timestamp: base + delta)
end

# Sanity: a timestamp inside the range does resolve, so a `-1` below means "beyond the last
# message" and not "this topic never resolves anything"
in_range = Karafka::Admin.read_partition_offsets(
  { topic => [{ partition: 0, offset: base + 10_000 }] }
).first

assert_equal 1, in_range[:offset]

beyond = Karafka::Admin.read_partition_offsets(
  { topic => [{ partition: 0, offset: base + 600_000 }] }
).first

assert_equal(-1, beyond[:offset])
assert_equal(-1, beyond[:timestamp])
assert_equal nil, beyond[:leader_epoch]

# It must not be confused with the end offset, which is what a caller would wrongly get if the
# sentinel were normalized away
latest = Karafka::Admin.read_partition_offsets(
  { topic => [{ partition: 0, offset: :latest }] }
).first

assert_equal deltas.size, latest[:offset]
assert beyond[:offset] != latest[:offset]
