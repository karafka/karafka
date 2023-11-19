# frozen_string_literal: true

# Karafka should shutdown cooperative-sticky after first rebalance, even if the rebalance did
# not grant any assignments to Karafka
#
# We have one partition that we assign to a different consumer and then start karafka that should
# not get the assignment. Despite that it should close gracefully because it did went through
# one (empty) rebalance.

setup_karafka do |config|
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce(DT.topic, '1')

consumer = setup_rdkafka_consumer(
  'partition.assignment.strategy': 'cooperative-sticky'
)

other = Thread.new do
  consumer.subscribe(DT.topic)

  until DT.key?(:done)
    DT[:ok] = true if consumer.poll(100)
    sleep(0.1)
  end

  consumer.close
end

sleep(0.1) until DT.key?(:ok)

start_karafka_and_wait_until do
  sleep(5)
  true
end

sleep(1)

DT[:done] = true

other.join
