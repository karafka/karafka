# frozen_string_literal: true

# User should be able to redefine the per consumer producer instance via direct `#producer`
# redefinition. It should be then fully usable

setup_karafka

# We set it to something that is not working (not this cluster)
Karafka::App.config.producer = WaterDrop::Producer.new do |config|
  config.deliver = true
  config.kafka = {
    'bootstrap.servers': 'localhost:999',
    'message.timeout.ms': 1_000
  }
end

SUPER_PRODUCER = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do
      DT[0] << 1
    end

    producer.produce_sync(topic: topic.name, payload: '')
  end

  def producer
    SUPER_PRODUCER
  end
end

draw_routes(Consumer)

SUPER_PRODUCER.produce_sync(topic: DT.topic, payload: '')

start_karafka_and_wait_until do
  DT[0].size >= 2
end
