# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should not resume when manual pause is in use for DLQ LRJ VP
# Pausing may be not predictable because of VPs

setup_karafka do |config|
  config.max_messages = 50
  config.pause_timeout = 2_000
  config.pause_max_timeout = 2_000
  config.pause_with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:paused] << messages.first.offset

    pause(messages.first.offset, 2_000)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    dead_letter_queue(topic: DT.topics[1])
    throttling(limit: 5, interval: 5_000)
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(200))

start_karafka_and_wait_until do
  DT[:paused].size >= 3
end

assert DT[:paused].include?(fetch_next_offset)
