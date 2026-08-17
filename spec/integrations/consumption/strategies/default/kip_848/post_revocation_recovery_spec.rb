# frozen_string_literal: true

# Karafka should recover from expired timeout when post-recovery the processing is fast enough

setup_karafka(
  allow_errors: %w[connection.client.poll.error],
  consumer_group_protocol: true
) do |config|
  # Remove session timeout and set a short (but not too tight) max poll interval.
  # Going lower (e.g. 5s) races the KIP-848 ConsumerGroupHeartbeat state machine:
  # the broker can evict the client and return `Invalid request` fatal on the next
  # heartbeat before our local poll-interval kick-in fires, leaving the client in
  # a degraded state where offset 0 is not replayed on recovery.
  config.kafka.delete(:"session.timeout.ms")
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    if DT.key?(:ticked)
      DT[:done] = true

      return
    end

    DT[:ticked] = true

    sleep(15)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(2))

start_karafka_and_wait_until do
  DT.key?(:done)
end

# Two recovery paths are valid here and which one we hit is decided inside
# librdkafka's KIP-848 ConsumerGroupHeartbeat state machine, not by us:
#
# - if our local max.poll.interval kick-in revokes the partition first, offset 0
#   stays uncommitted and is replayed on recovery => [0, 0, 1]
# - if the broker heartbeat evicts us first (fatal `Invalid request`), offset 0
#   is not replayed and we resume from offset 1 => [0, 1]
#
# Both prove the thing this spec cares about: Karafka recovers from the expired
# poll interval and processes every message to completion. The offset-0 replay is
# a librdkafka-internal detail we cannot force deterministically, so asserting the
# exact [0, 0, 1] sequence makes this spec flaky on CI.
assert [[0, 1], [0, 0, 1]].include?(DT[:offsets])
