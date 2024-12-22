# frozen_string_literal: true

# When consumer reclaims messages, it should not skip and should not have duplicated
# Marking should happen automatically

setup_karafka do |config|
  config.max_messages = 1_000
end

DT[:all] = {}
DT[:data] = {}

class Consumer < Karafka::BaseConsumer
  def initialized
    @buffer = []
  end

  def consume
    DT[:running] = true

    messages.each do |message|
      DT[:all][partition] ||= []
      DT[:all][partition] << message.offset

      DT[:data][partition] ||= []
      DT[:data][partition] << message.raw_payload.to_i

      raise if @buffer.include?(message.offset)

      @buffer << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 2)
  end
end

Thread.new do
  base = -1

  loop do
    accu = []

    100.times { accu << base += 1 }

    accu.map!(&:to_s)

    produce_many(DT.topic, accu, partition: 0)
    produce_many(DT.topic, accu, partition: 1)

    sleep(rand)
  rescue WaterDrop::Errors::ProducerClosedError, Rdkafka::ClosedProducerError
    break
  end
end

other = Thread.new do
  loop do
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DT.topic)
    consumer.each { break }

    2.times { consumer.poll(1_000) }

    consumer.close

    DT[:attempts] << true

    break if DT[:attempts].size >= 4
  end
end

start_karafka_and_wait_until do
  DT[:attempts].size >= 4
end

other.join

# This ensures we do not skip over offsets
DT[:all].each do |partition, offsets|
  previous = offsets.first - 1

  offsets.each do |offset|
    assert_equal(
      previous + 1,
      offset,
      [previous, offset, partition]
    )

    previous = offset
  end
end

# This ensures we do not skip over messages
DT[:data].each do |partition, counters|
  previous = counters.first - 1

  counters.each do |count|
    assert_equal(
      previous + 1,
      count,
      [previous, count, partition]
    )

    previous = count
  end
end
