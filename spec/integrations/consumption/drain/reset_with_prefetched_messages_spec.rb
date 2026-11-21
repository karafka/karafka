# frozen_string_literal: true

# When an error in the poll resets the client while librdkafka holds prefetched messages and the
# committed offset is behind the last message handed over, consumption should resume from the
# committed offset and continue with no gap.
#
# Small partition fetches and slow batches make librdkafka queue the messages before we poll again.

MESSAGES = 300
COMMITTED = 50

setup_karafka(allow_errors: %w[connection.listener.fetch_loop.error]) do |config|
  config.max_messages = 20
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
end

module PollFailure
  def batch_poll
    if DT.key?(:fail) && !DT.key?(:failed)
      DT[:failed] = true

      raise StandardError, "poll failure"
    end

    super
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(PollFailure)

Karafka.monitor.subscribe("client.reset") do
  DT[:resets] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.1)

    after_reset = DT.key?(:failed)

    messages.each do |message|
      (after_reset ? DT[:after] : DT[:before]) << message.offset

      # Before the reset, offsets are committed only up to COMMITTED
      mark_as_consumed!(message) if after_reset || message.offset < COMMITTED
    end

    DT[:fail] = true if messages.last.offset >= COMMITTED + 40
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(MESSAGES))

start_karafka_and_wait_until do
  DT[:after].include?(MESSAGES - 1)
end

assert_equal 1, DT[:resets].size
assert_equal (0..DT[:before].last).to_a, DT[:before]
assert DT[:before].last >= COMMITTED + 40
assert_equal (COMMITTED...MESSAGES).to_a, DT[:after]
