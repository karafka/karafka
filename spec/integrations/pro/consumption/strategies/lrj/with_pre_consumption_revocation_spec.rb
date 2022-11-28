# frozen_string_literal: true

# When LRJ jobs are in the processing queue prior to being picked by the workers and those LRJ
# jobs get revoked, the job should not run.

setup_karafka do |config|
  config.concurrency = 1
end

create_topic(name: DT.topic, partitions: 2)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.last.partition
    sleep(5) while DT[:rebalanced].empty?
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

produce_many(DT.topic, DT.uuids(20), partition: 0)
produce_many(DT.topic, DT.uuids(20), partition: 1)

start_karafka_and_wait_until do
  if DT[0].size >= 1
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
