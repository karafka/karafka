# frozen_string_literal: true

# We should be able to create a swarm with static members that can go up and down and receive same
# assignments.
#
# They also should not conflict with each other meaning each of them should consume some data and
# there should be no fencing

setup_karafka do |config|
  config.swarm.nodes = 2
  config.kafka[:"group.instance.id"] = SecureRandom.uuid
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts("#{partition}-#{Process.pid}")
  end
end

draw_topics do
  topic DT.topic do
    partitions 10
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

10.times do |partition|
  produce_many(DT.topic, DT.uuids(10), partition: partition)
end

results = {}
producer = nil

# No specs needed because if fenced, will fail
start_karafka_and_wait_until(mode: :swarm) do
  # Groups form without an initial rebalance delay, so the first node may get all the partitions
  # and drain the initial data before the second one joins. We keep producing so both nodes have
  # something to consume once assigned. The supervisor closes `Karafka.producer` before forking,
  # hence a dedicated one created post-fork.
  producer ||= WaterDrop::Producer.new do |producer_config|
    producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  end

  10.times do |partition|
    producer.produce_sync(topic: DT.topic, payload: "1", partition: partition)
  end

  while READER.wait_readable(1)
    partition_id, pid = READER.gets.strip.split("-")
    results[pid] ||= Set.new
    results[pid] << partition_id
  end

  results.size == 2 && results.values.all? { |sub| sub.size >= 2 }
end

producer.close
