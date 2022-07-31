# frozen_string_literal: true

# When a job is marked as lrj and a partition is lost, we should be able to get info about this
# by calling the `#revoked?` method.

TOPIC = 'integrations_04_02'

setup_karafka do |config|
  config.max_messages = 10
  config.max_wait_time = 5_000
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.license.token = pro_license_token
  config.concurrency = 10
  config.shutdown_timeout = 120_000
  config.initial_offset = 'latest'
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    DataCollector[:owned] << messages.metadata.partition

    messages.each do
      sleep(0.1) while !revoked? && DataCollector[:revoked].size < 2

      DataCollector[:revoked] << messages.metadata.partition
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic TOPIC do
      consumer Consumer
      long_running_job true
    end
  end
end

# We need a second producer to trigger a rebalance
consumer = setup_rdkafka_consumer

Thread.new do
  sleep(0.1) until Karafka::App.running?
  sleep(10)

  consumer.subscribe(TOPIC)
  consumer.poll(1_000)
end

Thread.new do
  sleep(0.1) until Karafka::App.running?

  5.times do
    10.times do
      produce(TOPIC, '1', partition: 0)
      produce(TOPIC, '1', partition: 1)
    rescue StandardError
      nil
    end

    sleep(5)
  end
end

start_karafka_and_wait_until do
  DataCollector[:revoked].uniq.size >= 2
end

# Both partitions should be revoked
assert_equal [0, 1], DataCollector[:revoked].uniq.sort.to_a

consumer.close
