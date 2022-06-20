# frozen_string_literal: true

# When there is a rebalance and we get the partition back, we should start consuming with a new
# consumer instance. We should use one before and one after we got the partition back.

TOPIC = 'integrations_11_02'

setup_karafka do |config|
  config.license.token = pro_license_token
  # We need 4: two partitions processing and non-blocking revokes
  config.concurrency = 4
  config.shutdown_timeout = 60_000
  config.initial_offset = 'latest'
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    # We should never try to consume new batch with a revoked consumer
    # This is just an extra test to make sure things work as expected
    exit! 5 if revoked?

    partition = messages.metadata.partition

    messages.each do |message|
      return unless mark_as_consumed!(message)
    end

    DataCollector["#{partition}-object_ids"] << object_id

    sleep 1
  end

  def revoked
    DataCollector[:revoked] << true
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

Thread.new do
  loop do
    2.times do
      produce(TOPIC, '1', partition: 0)
      produce(TOPIC, '1', partition: 1)
    end

    sleep(0.5)
  rescue StandardError
    nil
  end
end

# We need a second producer to trigger a rebalance
consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(0.1) until got_both?

  sleep(2)

  consumer.subscribe(TOPIC)

  consumer.each do |message|
    DataCollector[:jumped] << message

    consumer.store_offset(message)
    consumer.commit(nil, false)

    sleep 10

    break if DataCollector[:jumped].size >= 2
  end

  consumer.close
end

# This part makes sure we do not run rebalance until karafka got both partitions work to do
def got_both?
  DataCollector['0-object_ids'].uniq.size >= 1 &&
    DataCollector['1-object_ids'].uniq.size >= 1
end

start_karafka_and_wait_until do
  got_both? && (
    DataCollector['0-object_ids'].uniq.size >= 2 ||
      DataCollector['1-object_ids'].uniq.size >= 2
  )
end

other.join

revoked_partition = DataCollector[:jumped].last.partition

# There should be two instances of the consumer in use. One before the revoke and one after we
# lost the partition and when we got it back
assert_equal 2, DataCollector.data["#{revoked_partition}-object_ids"].uniq.size
assert_equal [true], DataCollector[:revoked]
