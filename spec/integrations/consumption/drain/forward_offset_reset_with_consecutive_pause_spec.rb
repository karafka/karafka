# frozen_string_literal: true

# When records ahead of the consumer are deleted, its next fetch is out of range and librdkafka
# resets it forward to the new start. A `pause(:consecutive)` after that reset must resume right
# after the last consumed message: no deleted offset is delivered, nothing is consumed twice, and
# the drain plans no seek, as offsets only went forward.
#
# Small partition fetches and a small librdkafka queue keep the fetch position close to the
# consumer, so the deletion lands ahead of it. The partition is paused while the records are
# deleted, so nothing is fetched in between.

MESSAGES = 1_000
DELETED_UNTIL = 500

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.kafka[:"queued.max.messages.kbytes"] = 1
  config.max_messages = 20
end

track_drains

track_drain_seek_plans

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    last = messages.last.offset

    if !DT.key?(:deleted) && last >= 50
      DT[:deleted] = last
      pause(:consecutive, 2_000)
      Karafka::Admin.delete_records({ topic.name => [{ partition: partition, offset: DELETED_UNTIL }] })
    elsif !DT.key?(:paused) && last >= DELETED_UNTIL + 50
      DT[:paused] = last
      pause(:consecutive, 1_000)
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(MESSAGES))

start_karafka_and_wait_until do
  DT[:offsets].last == MESSAGES - 1
end

offsets = DT[:offsets]
before = offsets.take_while { |offset| offset < DELETED_UNTIL }

assert DT[:drains].any?(&:positive?)
assert DT.key?(:paused)
assert before.last < DELETED_UNTIL - 1, before.last
assert_equal (0..before.last).to_a, before
assert_equal (DELETED_UNTIL...MESSAGES).to_a, offsets.drop(before.size)
assert_equal [], DT[:drain_rewinds] + DT[:drain_alignments]
