# frozen_string_literal: true

# produce_sync to a brand-new topic: the delivery report for the very FIRST message can
# carry an invalid offset (-1001) even though the message actually lands. librdkafka does
# not always get the offset back in that first delivery report; every subsequent produce_sync
# returns a real, monotonically increasing offset, and all messages are stored and consumable
# regardless of what their reports said. This spec pins that behaviour so it can't surprise us.

setup_karafka

# Offset sentinel librdkafka returns when the offset is not available in the delivery report
INVALID_OFFSET = -1001

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed_offsets] << message.offset
      DT[:consumed_payloads] << message.raw_payload
    end
  end
end

# Do not pre-create the topic: we want the very first produce_sync to hit a brand-new topic and
# let the broker auto-create it, which is exactly the condition under which the -1001 report
# offset shows up.
draw_routes(Consumer, create_topics: false)

# Produce synchronously to a brand-new topic (DT.topic is unique per spec run), capturing the
# offset each delivery report carries.
5.times do |i|
  report = Karafka.producer.produce_sync(topic: DT.topic, payload: "message-#{i}")
  DT[:report_offsets] << report.offset
end

start_karafka_and_wait_until do
  DT[:consumed_offsets].size >= 5
end

# Every message lands and is consumable with real, sequential broker offsets, regardless of
# what the delivery reports returned - the first message is not lost when its report says -1001.
assert_equal 5, DT[:consumed_payloads].size
assert_equal((0..4).map { |i| "message-#{i}" }, DT[:consumed_payloads])
assert_equal [0, 1, 2, 3, 4], DT[:consumed_offsets]

# The first delivery report may carry the invalid sentinel (-1001) OR a real offset - both are
# acceptable, that first-message ambiguity is exactly the edge case being covered here.
first_report_offset = DT[:report_offsets].first
assert(
  first_report_offset == INVALID_OFFSET || first_report_offset >= 0,
  "First produce_sync report offset should be the invalid sentinel or a real offset, " \
  "got #{first_report_offset}"
)

# Every subsequent delivery report carries a real, monotonically increasing offset that matches
# the actual broker offset of that message.
subsequent_report_offsets = DT[:report_offsets][1..]

subsequent_report_offsets.each do |offset|
  assert offset >= 0, "Subsequent produce_sync report offset should be real (>= 0), got #{offset}"
end

assert_equal(
  subsequent_report_offsets.sort,
  subsequent_report_offsets,
  "Subsequent produce_sync report offsets should be monotonically increasing"
)

assert_equal(
  DT[:consumed_offsets][1..],
  subsequent_report_offsets,
  "Delivery reports after the first should match the real broker offsets"
)
