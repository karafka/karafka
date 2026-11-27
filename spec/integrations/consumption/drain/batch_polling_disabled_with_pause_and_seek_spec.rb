# frozen_string_literal: true

# With `internal.connection.batch_polling` off, after a pause without an offset at the end of a
# batch, consumption should continue right after its last message, and after a seek back from
# consume it should continue from the seek offset. `poll_batch_nb` should never be called.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages that a drain
# would normally take.

MESSAGES = 100
PAUSE_AT = 30
SEEK_AT = 60
SEEK_TO = 40

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 20
  config.internal.connection.batch_polling = false
end

track_drains

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each do |message|
      DT[:offsets] << message.offset

      next unless message.offset == SEEK_AT && !DT.key?(:sought)

      DT[:sought] = true
      seek(SEEK_TO)

      return
    end

    return if DT.key?(:paused) || messages.last.offset < PAUSE_AT

    DT[:paused] = true
    DT[:paused_after] = messages.last.offset
    pause(:consecutive, 1_000)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(MESSAGES))

start_karafka_and_wait_until do
  DT[:offsets].last == MESSAGES - 1
end

assert DT[:drains].empty?
assert DT[:paused_after] < SEEK_AT
assert_equal (0..SEEK_AT).to_a + (SEEK_TO...MESSAGES).to_a, DT[:offsets]
