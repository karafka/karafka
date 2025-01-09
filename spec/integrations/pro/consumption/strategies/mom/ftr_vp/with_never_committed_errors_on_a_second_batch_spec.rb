# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# If we never mark offsets, upon errors we should start from beginning
# Throttling should not impact this in any way

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset

      raise if message.offset == 50
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    throttling(limit: 20, interval: 250)
    virtual_partitions(
      partitioner: ->(_msg) { rand(9) }
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:offsets].count(0) >= 5
end
