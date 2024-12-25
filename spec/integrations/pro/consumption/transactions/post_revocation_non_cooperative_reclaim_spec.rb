# frozen_string_literal: true

# When a transactional consumer goes into a non-cooperative-sticky rebalance and gets the
# partitions back, it should not have duplicated data.

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.kafka[:'isolation.level'] = 'read_committed'
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

    transaction do
      messages.each do |message|
        DT[:all][partition] ||= []
        DT[:all][partition] << message.offset

        DT[:data][partition] ||= []
        DT[:data][partition] << message.raw_payload.to_i

        raise if @buffer.include?(message.offset)

        @buffer << message.offset
        produce_async(topic: DT.topics[1], payload: '1')
      end

      unless DT.key?(:marked)
        mark_as_consumed(messages.last)
        DT[:marked] = true
      end
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    manual_offset_management(true)
    consumer Consumer
    config(partitions: 2)
  end

  topic DT.topics[1] do
    active false
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

consumer = setup_rdkafka_consumer

other = Thread.new do
  loop do
    consumer.subscribe(DT.topic)
    consumer.each { break }

    10.times { break if consumer.poll(1_000) }

    consumer.unsubscribe
    consumer.poll(1_000)

    DT[:attempts] << true

    break if DT[:attempts].size >= 10
  end
end

start_karafka_and_wait_until do
  DT[:attempts].size >= 10
end

other.join(10) || raise

consumer.close

# This ensures we do not skip over offsets
DT[:all].each do |partition, offsets|
  sorted = offsets.uniq.sort
  previous = sorted.first - 1

  sorted.each do |offset|
    # We check for 2 or less because of the transactional markers
    assert(
      ((previous + 1) - offset) <= 1,
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
