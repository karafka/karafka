# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When non-recoverable error happens and we want explicit marking, it should mark

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 10

      DT[:offsets] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0, mark_after_dispatch: true)
    manual_offset_management true
    throttling(limit: 50, interval: 5_000)
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:offsets].uniq.count >= 99
end

assert_equal 11, fetch_next_offset
