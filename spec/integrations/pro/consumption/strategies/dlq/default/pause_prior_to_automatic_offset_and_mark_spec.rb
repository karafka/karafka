# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When user pauses and marks by himself, we should not deal with this and let him do this.

setup_karafka do |config|
  config.max_messages = 50
  config.pause_timeout = 2_000
  config.pause_max_timeout = 2_000
  config.pause_with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:paused] << messages.first.offset
    DT[:last] << messages.last.offset

    pause(messages.first.offset, 1_000)

    mark_as_consumed(messages.last)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end
end

produce_many(DT.topic, DT.uuids(200))

start_karafka_and_wait_until do
  DT[:paused].size >= 3
end

assert_equal fetch_next_offset, DT[:last].max + 1
