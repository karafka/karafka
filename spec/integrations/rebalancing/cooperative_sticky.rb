# frozen_string_literal: true

# Karafka should support a cooperative-sticky rebalance strategy without any problems

setup_karafka do |config|
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
end

# We use a lot of partitions to make sure we never revoke part of them on rebalances
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
  def consume; end

  def on_revoked
    DT[:revoked] << messages.metadata.partition
  end
end

draw_routes(Consumer)

consumer = setup_rdkafka_consumer(
  'partition.assignment.strategy': 'cooperative-sticky'
)

other = Thread.new do
  sleep(10)
  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:picked] << message.partition

    break if DT[:picked].uniq.size >= 2
  end

  sleep(5)

  consumer.close
end

start_karafka_and_wait_until do
  other.join

  true
end

assert_equal DT[:revoked].uniq.sort, DT[:picked].uniq.sort
assert DT[:revoked].uniq.size < 5
