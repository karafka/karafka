# frozen_string_literal: true

# An Integer `:offset` is a timestamp in milliseconds and must resolve to the first offset AT OR
# AFTER it. That contract has three in-range cases worth pinning: a timestamp landing exactly on a
# message (inclusive, so it resolves to that message and not the next one), a timestamp falling
# between two messages, and a timestamp before the first message.
#
# The resolved `:timestamp` is the matched message's own timestamp. Together with `:max_timestamp`
# this is the only place that field is not `-1`, so it is asserted rather than merely checked for
# presence.

setup_karafka

topic = DT.topic

Karafka::Admin.create_topic(topic, 1, 1)

base = (Time.now.to_f * 1000).to_i - 600_000

# Ascending timestamps, 10s apart, at offsets 0..3
deltas = [0, 10_000, 20_000, 30_000]

deltas.each_with_index do |delta, index|
  produce(topic, index.to_s, partition: 0, timestamp: base + delta)
end

# @param topic [String] topic to query
# @param timestamp [Integer] timestamp in milliseconds
# @return [Hash] single partition offset result
def offset_at(topic, timestamp)
  Karafka::Admin.read_partition_offsets(
    { topic => [{ partition: 0, offset: timestamp }] }
  ).first
end

# --- exactly on a message timestamp: at-or-after is inclusive ---
exact = offset_at(topic, base + 10_000)

assert_equal 1, exact[:offset]
assert_equal base + 10_000, exact[:timestamp]

# --- between two messages: resolves to the first one after it, never the one before ---
between = offset_at(topic, base + 15_000)

assert_equal 2, between[:offset]
assert_equal base + 20_000, between[:timestamp]

# --- before the first message: resolves to the earliest offset ---
before = offset_at(topic, base - 30_000)

assert_equal 0, before[:offset]
assert_equal base, before[:timestamp]
