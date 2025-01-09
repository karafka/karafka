# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using manual offset management and not marking anything at all, we should not change
# offsets until DLQ as long as DLQ has an explicit post-error marking (which is not the default)

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Mark so throttle won't start from 0
      mark_as_consumed(message) if message.offset == 4

      raise StandardError if message.offset == 5

      DT[0] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue topic: DT.topics[1], max_retries: 1, mark_after_dispatch: true
    long_running_job true
    manual_offset_management true
    throttling(limit: 5, interval: 5_000)
  end
end

payloads = DT.uuids(50)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

assert_equal 6, fetch_next_offset
