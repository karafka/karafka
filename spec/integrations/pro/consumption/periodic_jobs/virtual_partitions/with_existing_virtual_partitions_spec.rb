# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we tick on existing VPs, they all should tick

setup_karafka do |config|
  config.max_messages = 50
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def tick
    DT[:ticks] << object_id
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )
  end
end

elements = DT.uuids(500)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:ticks].uniq.size >= 10
end

assert_equal 10, DT[:ticks].uniq.size
