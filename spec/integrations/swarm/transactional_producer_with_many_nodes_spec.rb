# frozen_string_literal: true

# When the default producer is transactional, each swarm node should get its own stable
# transactional.id, so nodes can run transactions at the same time without fencing each other

setup_karafka do |config|
  config.swarm.nodes = 2
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
      producer.produce_async(topic: DT.topics[1], payload: "1")
    end

    WRITER.puts("#{Process.pid}:#{producer.config.kafka[:"transactional.id"]}")
    WRITER.flush
  end
end

draw_topics do
  topic DT.topics[0] do
    partitions 2
  end

  topic DT.topics[1] do
    partitions 1
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end
end

producer = nil
results = {}

start_karafka_and_wait_until(mode: :swarm) do
  # Keep producing so both nodes get data (Karafka.producer is closed pre-fork)
  producer ||= WaterDrop::Producer.new do |producer_config|
    producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  end

  2.times do |partition|
    producer.produce_sync(topic: DT.topics[0], payload: "1", partition: partition)
  end

  while READER.wait_readable(1)
    pid, transactional_id = READER.gets.strip.split(":")
    results[pid] = transactional_id
  end

  results.size == 2
end

producer.close

assert_equal(
  %W[#{TRANSACTIONAL_ID}_0 #{TRANSACTIONAL_ID}_1],
  results.values.sort
)
