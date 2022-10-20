# frozen_string_literal: true

# Karafka will run a full rebalance in case we use cooperative-sticky but force commit when
# rebalance happens. This is how `librdkafka` works

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
end

create_topic(partitions: 5)

Thread.new do
  loop do
    begin
      produce(DT.topic, '1', partition: 0)
      produce(DT.topic, '2', partition: 1)
      produce(DT.topic, '3', partition: 2)
      produce(DT.topic, '4', partition: 3)
      produce(DT.topic, '5', partition: 4)
    rescue WaterDrop::Errors::ProducerClosedError
      break
    end

    sleep(1)
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed! messages.last
  end

  def on_revoked
    DT[:revoked] << messages.metadata.partition
  end
end

draw_routes(Consumer)


# We do it twice as it's an edge case that can but does not have to happen
# It should not happen if sync marking is not used though
other = Thread.new do
  2.times do
    consumer = setup_rdkafka_consumer(
      'partition.assignment.strategy': 'cooperative-sticky'
    )

    sleep(10)
    consumer.subscribe(DT.topic)

    consumer.each do |message|
      DT[:picked] << message.partition

      break if DT[:picked].uniq.size >= 2
    end

    sleep(5)

    consumer.close
  end
end

start_karafka_and_wait_until do
  other.join

  true
end

assert_equal [0, 1, 2, 3, 4], DT.data[:revoked].sort.uniq
