# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we start processing VP work with LRJ and some of the virtual partitions get revoked, they
# should not run if they were in the jobs queue.

setup_karafka do |config|
  config.max_messages = 1_000
  config.max_wait_time = 5_000
  config.concurrency = 1
end

MUTEX = Mutex.new

class Consumer < Karafka::BaseConsumer
  def consume
    return if messages.size <= 1

    DT[0] << messages.size

    sleep(5) while DT[:rebalanced].empty?

    sleep(1)
  end
end

ITERATOR = (1..1_000_000).each

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    virtual_partitions(
      partitioner: ->(_) { ITERATOR.next % 50 },
      max_partitions: 100
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  if DT.key?(0)
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DT.topic)
    consumer.poll(1_000)
    consumer.close

    sleep(1)

    DT[:rebalanced] << true

    true
  else
    false
  end
end

assert_equal 1, DT[0].size
