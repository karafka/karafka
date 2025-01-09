# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we tick on one VP and more appear, they should start ticking as well

setup_karafka do |config|
  config.max_messages = 50
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:appeared] = Time.now
  end

  def tick
    DT[:ticks] << [object_id, Time.now]
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

Thread.new do
  sleep(0.1) until DT[:ticks].size >= 2

  elements = DT.uuids(500)
  produce_many(DT.topic, elements)
end

start_karafka_and_wait_until do
  DT[:ticks].map(&:first).uniq.size >= 10
end

assert_equal 10, DT[:ticks].map(&:first).uniq.size

assert_equal 10, DT[:ticks].select { |tick| tick.last >= DT[:appeared] }.map(&:first).uniq.size
assert_equal 1, DT[:ticks].select { |tick| tick.last < DT[:appeared] }.map(&:first).uniq.size
