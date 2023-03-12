# frozen_string_literal: true

# Karafka should support a cooperative-sticky rebalance strategy without any problems

setup_karafka do |config|
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def on_revoked
    DT[:revoked] << messages.metadata.partition
  end
end

draw_routes do
  topic DT.topic do
    # We use a lot of partitions to make sure we never revoke part of them on rebalances
    config(partitions: 10)
    consumer Consumer
  end
end

Thread.new do
  loop do
    begin
      10.times do |i|
        produce(DT.topic, (i + 1).to_s, partition: i)
      end
    rescue WaterDrop::Errors::ProducerClosedError
      break
    end

    sleep(1)
  end
end

consumer = setup_rdkafka_consumer(
  'partition.assignment.strategy': 'cooperative-sticky'
)

other = Thread.new do
  sleep(10)
  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:picked] << message.partition

    break if DT[:picked].size >= 200
  end

  sleep(5)
end

start_karafka_and_wait_until do
  other.join

  true
end

assert_equal DT[:revoked].uniq.sort, DT[:picked].uniq.sort
assert DT[:revoked].uniq.size < 10

consumer.close
