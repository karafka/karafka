# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should throttle only the partition that hit limits and not the other one.

setup_karafka

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
      DT[:messages_times] << Time.now.to_f
    end
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do
      DT[:non_limited] << Time.now.to_f
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer1
    dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    throttling(
      limit: 2,
      interval: 60_000
    )
    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )
  end

  topic DT.topics[1] do
    consumer Consumer2
    throttling(
      limit: 1_000,
      interval: 1_000
    )
  end
end

Karafka.monitor.subscribe 'filtering.throttled' do
  DT[:times] << Time.now.to_f
end

elements = DT.uuids(100)
produce_many(DT.topics[0], elements)

elements = DT.uuids(999)
produce_many(DT.topics[1], elements)

start_karafka_and_wait_until do
  DT[:non_limited].size >= 999
end

assert DT[0].size < 3
