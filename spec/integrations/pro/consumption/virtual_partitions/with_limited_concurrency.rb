# frozen_string_literal: true

# When using Virtual Partitions with limited max partitions, VP should not occupy all the threads
# but it should use at most what was allowed. This allows for having some worker threads that are
# always available for other work.

setup_karafka do |config|
  config.license.token = pro_license_token
  config.concurrency = 3
  config.max_messages = 1_000
  config.max_wait_time = 1_000
end

create_topic(name: DT.topics[0])

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    times = []

    times << Time.now
    sleep(10) unless messages.count == 1
    times << Time.now

    DT[:times] << times

    DT[:messages] << messages.count
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topics[0] do
      consumer Consumer

      virtual_partitions(
        max_partitions: 2,
        partitioner: ->(msg) { msg.raw_payload }
      )
    end
  end
end

produce_many(DT.topics[0], DT.uuids(100))

start_karafka_and_wait_until do
  DT[:messages].sum >= 100
end

class Range
  def overlaps?(other)
    cover?(other.first) || other.cover?(first)
  end
end

overlaps = []

DT[:times].each do |time_range|
  range1 = (time_range[0]..time_range[1])

  overlaps << DT[:times].count do |time_range2|
    range2 = (time_range2[0]..time_range2[1])
    range1.overlaps?(range2)
  end
end

assert overlaps.max <= 2
