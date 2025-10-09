# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should stop fast and not process all in batch and offset position should be preserved

setup_karafka do |config|
  config.concurrency = 1
  config.max_messages = 100
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    each do |message|
      sleep(message.offset % 3)
      DT[:offsets] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    adaptive_iterator(
      active: true,
      safety_margin: 1
    )
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:offsets].size >= 3
end

assert_equal DT[:offsets].last + 1, fetch_next_offset
