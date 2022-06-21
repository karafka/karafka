# frozen_string_literal: true

# When Karafka tries to commit offset after the partition was revoked in a blocking way,
# it should return false for partition that was lost. It should also indicate when lrj is running
# that the revocation took place. It should indicate this before we mark as consumed as this state
# should be set on a consumer in the revocation job.
#
# This will work only when we have enough threads to be able to run the revocation jobs prior to
# finishing the processing. Otherwise when enqueued, will run after (for this we have another spec)

TOPIC = 'integrations_7_02'

setup_karafka do |config|
  config.license.token = pro_license_token
  # We need 4: two partitions processing and non-blocking revokes
  config.concurrency = 4
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    partition = messages.metadata.partition

    return if @slept

    @slept = true
    sleep(15)
    # Here we already should be revoked and we should know about it as long as we have enough
    # threads to handle this
    DataCollector["#{partition}-revoked"] << revoked?
    # We should not own this partition anymore
    DataCollector["#{partition}-marked"] << mark_as_consumed!(messages.last)
    # Here things should not change for us
    DataCollector["#{partition}-revoked"] << revoked?
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
  (
    DataCollector['0-revoked'].size >= 1 ||
      DataCollector['1-revoked'].size >= 1
  ) && DataCollector[:revoked_data].size >= 1
end

consumer.close

revoked_partition = DataCollector[:revoked_data].first

assert_equal [true, true], DataCollector["#{revoked_partition}-revoked"]
assert_equal [false], DataCollector["#{revoked_partition}-marked"]
