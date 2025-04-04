# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When a job is marked as vp and there is a rebalance, we should be aware that our current
# instance had the partition revoked even if it is assigned back. The assignment back should again
# start from where it left

setup_karafka do |config|
  config.max_messages = 5
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(1)

    messages.each do |message|
      DT[0] << message.raw_payload
    end

    # This will ensure we can move forward
    mark_as_consumed(messages.first)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(_) { rand }
    )
  end
end

# We need a second producer so we are sure that there was no revocation due to a timeout
consumer = setup_rdkafka_consumer

Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)

  consumer.each do
    # This should never happen.
    # We have one partition and it should be karafka that consumes it
    exit! 5
  end
end

payloads = DT.uuids(20)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

# There should be no duplication as our pause should be running for as long as it needs to and it
# should be un-paused only when done
assert_equal payloads.sort, DT[0].sort

consumer.close
