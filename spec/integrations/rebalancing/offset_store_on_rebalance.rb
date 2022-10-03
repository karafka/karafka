# frozen_string_literal: true

# Karafka should store offsets upon rebalance on revocation.
# This reduces number of messages that have to be processed again.
#
# This specs ensures, that we flush offsets upon a rebalance

setup_karafka do |config|
  config.concurrency = 1
  # Basically not often enough to commit anything on rebalance
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
end

create_topic(partitions: 2)

Thread.new do
  loop do
    produce(DT.topic, '1', partition: 0)
    produce(DT.topic, '2', partition: 1)

    sleep(1)
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.partition] << message.offset
      p [message.partition, message.offset]
    end
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
    DT[:picked] << [message.partition, message.offset]

    break
  end

  consumer.close
end

start_karafka_and_wait_until do
  other.join

  # Give it time to potentially fetch the repeated messages once again prior to finishing
  sleep(60)

  true
end

p DT[0]
p DT[1]
p DT[:picked]
