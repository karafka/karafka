# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When periodic ticking is on but other consumers have some partitions, we should not tick on them
# as they are not assigned to us

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    DT[:ticks] << messages.metadata.partition
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    periodic true
  end
end

# Running this first will ensure we get one partition on second consumer first
consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topic)

10.times do
  consumer.poll(100)
  sleep(0.5)
end

start_karafka_and_wait_until do
  DT[:ticks].count >= 10
end

consumer.close

assert_equal 1, DT[:ticks].uniq.size
