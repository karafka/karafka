# frozen_string_literal: true

# When consumer looses the partition but later on gets it back, it should not have duplicates
# as long as marking always happened (which is the case in this scenario)
# There also should be no duplicates

setup_karafka do |config|
  config.max_messages = 1_000
  config.kafka[:"partition.assignment.strategy"] = "cooperative-sticky"
end

DT[:all] = { 0 => [], 1 => [] }
DT[:data] = { 0 => [], 1 => [] }

class Consumer < Karafka::BaseConsumer
  def initialized
    @buffer = []
  end

  def consume
    DT[:running] = true

    messages.each do |message|
      DT[:all][partition] << message.offset
      DT[:data][partition] << message.raw_payload.to_i

      raise if @buffer.include?(message.offset)

      @buffer << message.offset
    end

    mark_as_consumed(messages.last)
  end
end

draw_routes do
  topic DT.topics[0] do
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
    consumer = setup_rdkafka_consumer("partition.assignment.strategy": "cooperative-sticky")
    consumer.subscribe(DT.topic)

    consumer.each do |message|
      DT[:all][message.partition] << message.offset
      DT[:data][message.partition] << message.payload.to_i

      consumer.store_offset(message)
      consumer.commit

      break
    end

    consumer.close

    DT[:attempts] << true

    break if DT[:attempts].size >= 3
  end
end

start_karafka_and_wait_until do
  DT[:attempts].size >= 3
end

other.join

# This ensures we do not skip over offsets
DT[:all].each do |partition, offsets|
  sorted = offsets.uniq.sort
  previous = sorted.first - 1

  sorted.each do |offset|
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
  sorted = counters.uniq.sort
  previous = sorted.first - 1

  sorted.each do |count|
    assert_equal(
      previous + 1,
      count,
      [previous, count, partition]
    )

    previous = count
  end
end
