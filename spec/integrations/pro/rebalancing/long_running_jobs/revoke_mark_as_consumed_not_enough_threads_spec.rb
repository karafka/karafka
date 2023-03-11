# frozen_string_literal: true

# When Karafka tries to commit offset after the partition was revoked in a non-blocking way,
# it should return false for partition that was lost. It should also indicate when lrj is running
# that the revocation took place. It should not indicate this before we mark as consumed as this
# state could not be set on a consumer in the revocation job becuase it is pending in the queue.

setup_karafka do |config|
  config.concurrency = 2
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    partition = messages.metadata.partition

    return if @slept

    DT["#{partition}-revoked"] << revoked?

    @slept = true

    sleep(15)

    # Here we already should be revoked and we should know about it as long as we have enough
    # threads to handle this
    # We should not own this partition anymore
    DT["#{partition}-marked"] << mark_as_consumed(messages.last)
    # Here things should not change for us
    DT["#{partition}-revoked"] << revoked?
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

produce_many(DT.topic, DT.uuids(10), partition: 0)
produce_many(DT.topic, DT.uuids(10), partition: 1)

# We need a second producer to trigger a rebalance
consumer = setup_rdkafka_consumer

thread = Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:revoked_data] << message.partition

    break
  end
end

start_karafka_and_wait_until do
  (
    DT['0-revoked'].size >= 1 ||
      DT['1-revoked'].size >= 1
  ) && DT[:revoked_data].size >= 1
end

thread.join
consumer.close

revoked_partition = DT[:revoked_data].first

assert_equal [false, true], DT["#{revoked_partition}-revoked"]
assert_equal [false], DT["#{revoked_partition}-marked"]
