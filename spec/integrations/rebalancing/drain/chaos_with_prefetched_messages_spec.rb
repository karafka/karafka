# frozen_string_literal: true

# When consumers join and leave the consumer group at random for a few minutes while messages are
# produced all the time and many of them are prefetched and drained, no message should be skipped.
# Messages may be consumed again after a rebalance, but each partition should have continuity and
# every run of a consumer on a partition should be consecutive.

PARTITIONS = 3
CHAOS_TIME = 120

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 200
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      return unless mark_as_consumed!(message)

      DT[:runs][[partition, object_id]] << message.offset
      DT[:all][partition] << message.offset
    end
  end
end

DT[:runs] = Hash.new { |h, k| h[k] = [] }
DT[:all] = Hash.new { |h, k| h[k] = [] }
DT[:produced] = Hash.new(0)

draw_topics do
  topic DT.topic do
    partitions PARTITIONS
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

stop_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + CHAOS_TIME

producer = Thread.new do
  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < stop_at
    PARTITIONS.times do |partition|
      produce_many(DT.topic, DT.uuids(20), partition: partition)
      DT[:produced][partition] += 20
    end

    sleep(0.1)
  end
end

chaos = Array.new(2) do
  Thread.new do
    sleep(rand(2.0..5.0))

    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < stop_at
      consumer = setup_rdkafka_consumer
      consumer.subscribe(DT.topic)
      sleep(rand(1.0..4.0))
      consumer.close
      sleep(rand(0.5..3.0))
    end
  end
end

deadline = stop_at + 60

start_karafka_and_wait_until do
  next false if producer.alive? || chaos.any?(&:alive?)
  next true if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

  PARTITIONS.times.all? do |partition|
    DT[:all][partition].uniq.size >= DT[:produced][partition]
  end
end

PARTITIONS.times do |partition|
  assert_equal (0...DT[:produced][partition]).to_a, DT[:all][partition].uniq.sort
end

DT[:runs].each_value do |offsets|
  assert_equal (offsets.first..offsets.last).to_a, offsets
end
