# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When LRJ jobs are in the processing queue prior to being picked by the workers and those LRJ
# jobs get revoked, the job should not run.

setup_karafka do |config|
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.last.partition
    sleep(5) while DT[:rebalanced].empty?
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(20), partition: 0)
produce_many(DT.topic, DT.uuids(20), partition: 1)

start_karafka_and_wait_until do
  if DT.key?(0)
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DT.topic)
    consumer.poll(1_000)
    consumer.close

    DT[:rebalanced] << true

    sleep(1)

    true
  else
    false
  end
end

assert_equal 1, DT[0].uniq.size
