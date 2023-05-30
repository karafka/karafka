# frozen_string_literal: true

# When running lrj, Karafka should never run the shutdown operations while consumption is in
# progress

setup_karafka do |config|
  config.max_messages = 20
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if messages.count == 1

    sleep(15)

    DT[0] << Time.now
  end

  def shutdown
    DT[1] << Time.now
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
      manual_offset_management true
      throttling(limit: 1_000_000, interval: 100_000)
      virtual_partitions(
        partitioner: ->(_msg) { rand(9) }
      )
    end
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT.key?(0)
end

assert DT[0].last < DT[1].last
assert_equal 0, fetch_first_offset
