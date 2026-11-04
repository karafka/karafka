# frozen_string_literal: true

# Share group (KIP-932) consumers should be able to redefine their producer via direct `#producer`
# redefinition. It should be then fully usable even when the default one does not work.

setup_karafka

# We set it to something that is not working (not this cluster)
Karafka::App.config.producer = WaterDrop::Producer.new do |config|
  config.deliver = true
  config.kafka = {
    "bootstrap.servers": "localhost:999",
    "message.timeout.ms": 1_000
  }
end

SUPER_PRODUCER = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:payloads] << message.raw_payload
      mark_as_accepted(message)
    end

    producer.produce_sync(topic: topic.name, payload: "produced") if DT[:payloads].size == 1
  end

  def producer
    SUPER_PRODUCER
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

SUPER_PRODUCER.produce_sync(topic: DT.topic, payload: "initial")

start_karafka_and_wait_until do
  DT[:payloads].size >= 2
end

assert_equal %w[initial produced], DT[:payloads]

SUPER_PRODUCER.close
