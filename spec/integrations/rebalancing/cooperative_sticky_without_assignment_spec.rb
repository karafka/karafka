# frozen_string_literal: true

# When work already happens somewhere else and cooperative-sticky kicks in, we should not get
# the assignment but an event should propagate from the rebalance nonetheless

setup_karafka do |config|
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end
end

draw_routes(Consumer)
produce(DT.topic, '1')

Karafka.monitor.subscribe('rebalance.partitions_assigned') do
  DT[:stop] = true
end

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
  DT.key?(:stop)
end

sleep(1)

DT[:done] = true

other.join
