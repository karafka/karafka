# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we are over-saturated, the jobs that are in the queue should not run if the assignment
# was revoked even if the rebalance callback did not yet kick in. The `#revoked?` should be
# aware of unintended assignment.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
  config.max_messages = 1_000
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    return unless DT.key?(:enough)
    return if DT.key?(:second_poll)

    DT[:executed] << messages.metadata.partition

    sleep(15)
  end

  def revoked
    DT[:revoked] << messages.metadata.partition
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 3)
    consumer Consumer
  end
end

partitions = 0

Karafka.monitor.subscribe('connection.listener.fetch_loop.received') do |event|
  event.payload[:messages_buffer].each do
    partitions += 1
  end

  DT[:second_poll] = true if DT.key?(:enough)

  DT[:enough] = true if partitions > 2 && !DT.key?(:second_poll)
end

Thread.new do
  loop do
    3.times do |i|
      produce_many(DT.topic, DT.uuids(10), partition: i)
    end

    break if DT.key?(:enough)

    sleep(0.5)
  end
rescue WaterDrop::Errors::ProducerClosedError
  nil
end

# We need a second producer to trigger the rebalances
Thread.new do
  sleep(0.1) until DT.key?(:enough)

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)
  consumer.close
end

start_karafka_and_wait_until do
  DT[:revoked].size >= 1
end

assert_equal 1, DT[:executed].size
