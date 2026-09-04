# frozen_string_literal: true

# produce_sync to a brand-new topic: the delivery report for the very FIRST message can
# carry an invalid offset (-1001) even though the message actually lands. librdkafka does
# not always get the offset back in that first delivery report; every subsequent produce_sync
# returns the real offset the message was stored under. This spec pins that behaviour so it
# can't surprise us.

setup_karafka

# Offset sentinel librdkafka returns when the offset is not available in the delivery report
INVALID_OFFSET = -1001

# Do not pre-create the topic: we want the very first produce_sync to hit a brand-new topic and
# let the broker auto-create it, which is exactly the condition under which the -1001 report
# offset shows up.
draw_routes(create_topics: false) do
  topic DT.topic do
    active false
  end
end

# Produce synchronously to a brand-new topic (DT.topic is unique per spec run), capturing the
# offset each delivery report carries.
report_offsets = Array.new(5) do |i|
  Karafka.producer.produce_sync(topic: DT.topic, payload: "message-#{i}").offset
end

messages = Karafka::Admin.read_topic(DT.topic, 0, 5)
stored_offsets = messages.map(&:offset)

# Every message lands and is stored under a real, sequential offset, regardless of what the
# delivery reports returned - the first message is not lost when its report says -1001.
assert_equal 5, messages.size
assert_equal(Array.new(5) { |i| "message-#{i}" }, messages.map(&:raw_payload))
assert_equal [0, 1, 2, 3, 4], stored_offsets

# The first delivery report may carry the invalid sentinel (-1001) OR a real offset - both are
# acceptable, that first-message ambiguity is exactly the edge case being covered here.
assert(
  report_offsets.first == INVALID_OFFSET || report_offsets.first >= 0,
  "First produce_sync report offset should be the invalid sentinel or a real offset, " \
  "got #{report_offsets.first}"
)

# Every subsequent delivery report carries the real offset the message was stored under.
assert_equal(
  stored_offsets[1..],
  report_offsets[1..],
  "Delivery reports after the first should match the real stored offsets"
)
