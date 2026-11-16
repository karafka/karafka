# frozen_string_literal: true

# When the default producer is transactional and the swarm has one node, the node should keep the
# configured transactional.id unchanged

setup_karafka do |config|
  config.swarm.nodes = 1
end

TRANSACTIONAL_ID = SecureRandom.uuid

Karafka::App.config.producer = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.kafka[:"transactional.id"] = TRANSACTIONAL_ID
  producer_config.logger = Karafka::App.config.logger
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    producer.transaction do
      producer.produce_async(topic: DT.topic, payload: "1")
    end

    WRITER.puts(producer.config.kafka[:"transactional.id"])
    WRITER.flush
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until(mode: :swarm) do
  DT[:transactional_id] = READER.gets&.strip

  !DT[:transactional_id].nil?
end

assert_equal TRANSACTIONAL_ID, DT[:transactional_id]
