# frozen_string_literal: true

# When running LRJ jobs upon shutdown, those jobs will keep running until finished or until reached
# max wait time. During this time, the rebalance changes should propagate and we should be able
# to make decisions also based on the revocation status.

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 20
end

create_topic(partitions: 10)

10.times do |i|
  produce(DT.topic, (i + 1).to_s, partition: i)
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:started] << true

    # We use loop so in case this would not work, it will timeout and raise an error
    loop do
      sleep(0.1)

      next unless revoked?

      DT[:revoked] << true

      break
    end
  end

  def shutdown
    DT[:shutdown] << true
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

start_karafka_and_wait_until do
  if DT[:started].size >= 10
    # Trigger a rebalance here, it should revoke all partitions
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DT.topic)
    consumer.each { break }
    consumer.close

    true
  else
    false
  end
end

assert_equal [], DT[:shutdown], DT[:shutdown]
assert_equal 10, DT[:revoked].size, DT.data
