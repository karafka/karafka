# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should be able to just consume when throttling limits are not reached.
# DLQ should have nothing to do with this.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    manual_offset_management(true)
    throttling(
      limit: 1_000,
      interval: 60_000
    )
    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )
  end
end

# Should not happen
Karafka.monitor.subscribe 'filtering.throttled' do
  raise
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

# VPed, so not in order
assert_equal elements.sort, DT[0].sort
assert_equal 1, DT.data.size
assert fetch_next_offset.zero?
