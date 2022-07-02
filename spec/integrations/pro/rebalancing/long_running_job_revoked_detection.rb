# frozen_string_literal: true

# When a job is marked as lrj and a partition is lost, we should be able to get info about this
# by calling the `#revoked?` method.

TOPIC = 'integrations_04_02'

setup_karafka do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.license.token = pro_license_token
  config.concurrency = 10
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::Pro::BaseConsumer
  def initialize
    super
    @first = true
  end

  def consume
    messages.each do
      DataCollector[messages.metadata.partition] << true

      if revoked?
        DataCollector[:revoked] << messages.metadata.partition
        return
      end

      # First batch may be super small, so we skip it and wait for a bigger one
      unless @first
        # Sleep only once here, it's to make sure we exceed max poll
        sleep(@slept ? 1 : 15)
        @slept = true
      end

      @first = false
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

10.times do
  produce(TOPIC, '1', partition: 0)
  produce(TOPIC, '1', partition: 1)
end

# We need a second producer to trigger a rebalance
consumer = setup_rdkafka_consumer

Thread.new do
  sleep(10)

  consumer.subscribe(TOPIC)

  consumer.each do |message|
    DataCollector[:revoked_data] << message.partition
  end
end

start_karafka_and_wait_until do
  DataCollector[:revoked].size >= 2 && (
    DataCollector[0].size >= 10 ||
      DataCollector[1].size >= 10
  )
end

# Both partitions should be revoked
assert_equal [0, 1], DataCollector[:revoked].sort.to_a

consumer.close
