# frozen_string_literal: true

# With `acks: 0` the produce is fire-and-forget: the broker never acknowledges the write, so
# librdkafka never learns where the message was stored and every delivery report carries the
# -1001 sentinel instead of an offset. This is unconditional - it applies to every message
# produced through such a variant, not just the first one to a fresh topic.
#
# A control producer with default acks produces to its own topic, so a green run means "-1001
# comes from acks: 0" rather than "everything in this environment reports -1001". The control
# needs both its own producer and its own topic: `acks` is topic-level config, so once a
# producer has produced to a topic through an `acks: 0` variant, plain produces to that same
# topic on that same producer keep reporting the sentinel.
#
# We deliberately do not assert that the acks: 0 messages landed. That configuration offers no
# delivery guarantee at all, so asserting delivery would be asserting something it explicitly
# does not promise.

setup_karafka

# Offset sentinel librdkafka reports when no offset is available in the delivery report
INVALID_OFFSET = -1001

# How many messages each producer sends
MESSAGES_COUNT = 5

# Both topics are declared, so neither is auto-created and no warning exclusion is needed
draw_routes do
  topic DT.topics[0] do
    active false
  end

  topic DT.topics[1] do
    active false
  end
end

# An idempotent producer rejects an `acks: 0` variant outright, so this deliberately builds on
# the default, non-idempotent producer
acks_zero = Karafka.producer.with(topic_config: { acks: 0 })

acks_zero_offsets = Array.new(MESSAGES_COUNT) do |i|
  acks_zero.produce_sync(topic: DT.topics[0], payload: "acks-zero-#{i}").offset
end

control_producer = WaterDrop::Producer.new do |config|
  config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

control_offsets = Array.new(MESSAGES_COUNT) do |i|
  control_producer.produce_sync(topic: DT.topics[1], payload: "control-#{i}").offset
end

control_producer.close

# Every acks: 0 report carries the sentinel, not just the first
assert_equal(
  Array.new(MESSAGES_COUNT) { INVALID_OFFSET },
  acks_zero_offsets,
  "Every acks: 0 delivery report should carry #{INVALID_OFFSET}, got #{acks_zero_offsets}"
)

# The control reports real offsets, proving the sentinel above comes from acks: 0. Its first
# message is skipped so this does not overlap with the separate first-produce edge case.
assert(
  control_offsets[1..].all? { |offset| offset >= 0 },
  "Control producer with default acks should report real offsets, got #{control_offsets}"
)
