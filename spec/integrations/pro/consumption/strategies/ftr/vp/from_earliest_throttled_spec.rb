# frozen_string_literal: true

# Karafka should be able to easily consume all the messages from earliest (default) using multiple
# threads based on the used virtual partitioner. We should use more than one thread for processing
# of all the messages and we should throttle the performance to make sure we do not do it too fast

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    # just a check that we have this api method included in the strategy
    collapsed?

    messages.each do |message|
      DT[object_id] << message.offset
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      throttling(limit: 20, interval: 5_000)
      virtual_partitions(
        partitioner: ->(msg) { msg.raw_payload }
      )
    end
  end
end

produce_many(DT.topic, DT.uuids(100))

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DT.data.values.map(&:size).sum >= 100
end

time_taken = Time.now.to_f - started_at

# Make sure we do not process fast and things are throttled.
# 5 x 5 seconds of throttle is at least 25 seconds
assert time_taken > 25

# Since Ruby hash function is slightly nondeterministic, not all the threads may always be used
# but in general more than 5 need to be always
assert DT.data.size >= 5

# On average we should have similar number of messages
sizes = DT.data.values.map(&:size)
average = sizes.sum / sizes.count
# Small deviations may be expected
assert average >= 8
assert average <= 12

# All data within partitions should be in order
DT.data.each do |_object_id, offsets|
  previous_offset = nil

  offsets.each do |offset|
    unless previous_offset
      previous_offset = offset
      next
    end

    assert previous_offset < offset
  end
end
