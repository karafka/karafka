# frozen_string_literal: true

# Non Pro Karafka handles oversaturated jobs on involuntary revocation as any others. That is,
# it does not provide extended processing warranties and will run those jobs as any others.
#
# This spec demonstrates and checks that. Extended saturation warranties are part of the Pro.

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

    sleep(11)
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

Karafka.monitor.subscribe('connection.listener.fetch_loop.received') do |event|
  partitions = 0

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

assert DT[:executed].size > 1
