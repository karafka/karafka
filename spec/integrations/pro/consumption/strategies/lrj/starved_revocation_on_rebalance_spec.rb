# frozen_string_literal: true

# When running lrj, on revocation Karafka should change the revocation state even when there are
# no available slots for processing

setup_karafka do |config|
  config.max_messages = 5
  config.concurrency = 2
end

DT[:started] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    until revoked?
      sleep(0.1)
      DT[:started] << object_id
    end

    DT[:revoked] << true
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      config(partitions: 2)
      consumer Consumer
      long_running_job true
    end
  end
end

produce(DT.topic, '0', partition: 0)
produce(DT.topic, '1', partition: 1)

start_karafka_and_wait_until do
  if DT[:started].size >= 2
    if DT[:rebalanced].empty?
      consumer = setup_rdkafka_consumer
      consumer.subscribe(DT.topic)
      consumer.poll(1_000)
      consumer.close
      DT[:rebalanced] << true
    end

    DT[:revoked].size >= 2
  else
    false
  end
end

# No spec needed. If revocation would not happen as expected while all the threads are occupied,
# This would hang forever.
