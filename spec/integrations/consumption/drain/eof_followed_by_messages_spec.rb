# frozen_string_literal: true

# When an eof of a partition is followed by more messages of the same partition among the already
# fetched ones, the partition is not at its end anymore. `eofed?` should be true only when the
# last consumed message really was the last one at that time, messages should arrive in order and
# the next real eof should still be reported.
#
# While the first batch is consumed, we produce in two steps with a pause between them, so
# librdkafka queues the first step messages, their eof, the second step messages and their eof.
# The `max_messages` limit cuts the batch after the first eof, before the second one.

FIRST_STEP = 5
SECOND_STEP = 10
# Offsets at which the partition was at its end
ENDS = [1, 1 + FIRST_STEP, 1 + FIRST_STEP + SECOND_STEP].freeze

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.max_messages = 11
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    DT[:eofs] << (DT[:offsets].last + 1) if eofed?

    return if DT.key?(:produced)

    DT[:produced] = true

    produce_many(DT.topic, DT.uuids(FIRST_STEP))
    sleep(2)
    produce_many(DT.topic, DT.uuids(SECOND_STEP))
    sleep(2)
  end

  def eofed
    DT[:eofs] << (DT[:offsets].last + 1)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    eofed true
  end
end

produce(DT.topic, "0")

consumed_at = nil

start_karafka_and_wait_until do
  consumed_at ||= Time.now if DT[:offsets].size >= ENDS.last

  # Give the last eof time to arrive once everything is consumed, but do not wait forever when it
  # got lost
  DT[:eofs].include?(ENDS.last) || (consumed_at && Time.now - consumed_at > 20)
end

assert_equal (0...ENDS.last).to_a, DT[:offsets]
# eofed only at the real ends of the partition and the last one is reported
assert_equal [], DT[:eofs] - ENDS
assert DT[:eofs].include?(ENDS.last)
