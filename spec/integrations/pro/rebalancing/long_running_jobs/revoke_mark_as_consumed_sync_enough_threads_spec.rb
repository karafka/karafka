# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When Karafka tries to commit offset after the partition was revoked in a blocking way,
# it should return false for partition that was lost. It should also indicate when lrj is running
# that the revocation took place. It should indicate this before we mark as consumed as this state
# should be set on a consumer in the revocation job.
#
# This will work only when we have enough threads to be able to run the revocation jobs prior to
# finishing the processing. Otherwise when enqueued, will run after (for this we have another spec)

setup_karafka do |config|
  # We need 4: two partitions processing and non-blocking revokes
  config.concurrency = 4
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    partition = messages.metadata.partition

    return if @slept

    @slept = true
    sleep(15)
    # Here we already should be revoked and we should know about it as long as we have enough
    # threads to handle this
    DT["#{partition}-revoked"] << revoked?
    # We should not own this partition anymore
    DT["#{partition}-marked"] << mark_as_consumed!(messages.last)
    # Here things should not change for us
    DT["#{partition}-revoked"] << revoked?
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(10), partition: 0)
produce_many(DT.topic, DT.uuids(10), partition: 1)

# We need a second producer to trigger a rebalance
consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:revoked_data] << message.partition

    break
  end
end

start_karafka_and_wait_until do
  (DT.key?('0-revoked') || DT.key?('1-revoked')) && DT.key?(:revoked_data)
end

other.join
consumer.close

revoked_partition = DT[:revoked_data].first

assert_equal [true, true], DT["#{revoked_partition}-revoked"]
assert_equal [false], DT["#{revoked_partition}-marked"]
