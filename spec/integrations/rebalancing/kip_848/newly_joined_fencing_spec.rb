# frozen_string_literal: true

# Test rebalancing with KIP-848 by verifying that new consumer joining with same group instance id
# should be fenced
#
# If new consumer is not fenced, it will run forever and spec will timeout

GROUP_INSTANCE_ID = SecureRandom.uuid

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  config.kafka[:'group.protocol'] = 'consumer'
  config.kafka[:'group.instance.id'] = GROUP_INSTANCE_ID
  config.kafka.delete(:'partition.assignment.strategy')
  config.kafka.delete(:'heartbeat.interval.ms')
end

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:errored] = event[:error]
end

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 5)
  end
end

produce(DT.topic, '1')

thread = Thread.new do
  consumer = Rdkafka::Config.new(
    Karafka::Setup::AttributesMap.consumer(
      'bootstrap.servers': Karafka::App.config.kafka[:'bootstrap.servers'],
      'group.id': Karafka::App.consumer_groups.first.id,
      'group.protocol': 'consumer',
      'group.instance.id': "#{GROUP_INSTANCE_ID}_0",
      'auto.offset.reset': 'earliest'
    )
  ).consumer

  consumer.subscribe(DT.topic)

  until DT.key?(:errored)
    next unless consumer.poll(1_000)

    DT[:balanced] = true
  end

  consumer.close
end

sleep(0.1) until DT.key?(:balanced)

sleep(1)

start_karafka_and_wait_until do
  DT.key?(:errored)
end

thread.join
