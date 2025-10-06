# frozen_string_literal: true

# Karafka should allow for running a single consumer group with new protocol members joining.
# It should allow for transition.
#
# Note: it is not recommended to do so.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 5)
  end
end

5.times do |i|
  produce_many(DT.topic, DT.uuids(100), partition: i)
end

thread = Thread.new do
  consumer = Rdkafka::Config.new(
    Karafka::Setup::AttributesMap.consumer(
      'bootstrap.servers': Karafka::App.config.kafka[:'bootstrap.servers'],
      'group.id': Karafka::App.consumer_groups.first.id,
      'group.protocol': 'consumer',
      'auto.offset.reset': 'earliest',
      'enable.auto.offset.store': false
    )
  ).consumer

  consumer.subscribe(DT.topic)

  until DT.key?(:done)
    message = consumer.poll(1_000)

    next unless message

    DT[:messaged] = true
  end

  consumer.close
end

sleep(0.1) until DT.key?(:messaged)

start_karafka_and_wait_until do
  DT.key?(:done)
end

thread.join
