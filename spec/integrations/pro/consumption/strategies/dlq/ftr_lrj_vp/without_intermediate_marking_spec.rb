# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should mark correctly the final offset of collective group upon finish

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 1000
  config.concurrency = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { DT[0] << true }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    max_messages 1000
    long_running_job true
    dead_letter_queue topic: DT.topics[1], max_retries: 4
    virtual_partitions(
      partitioner: ->(_) { rand(1000) }
    )
    throttling(
      limit: 200,
      interval: 1_000
    )
  end
end

produce_many(DT.topic, DT.uuids(1000))

start_karafka_and_wait_until do
  DT[0].size >= 1000
end

assert_equal 1000, fetch_next_offset
