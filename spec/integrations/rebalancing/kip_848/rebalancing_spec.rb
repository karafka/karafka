# frozen_string_literal: true

# Test rebalancing with KIP-848 by verifying partition assignment changes
# when a second consumer joins the group

setup_karafka do |config|
  config.kafka[:'group.protocol'] = 'consumer'
  config.kafka.delete(:'partition.assignment.strategy')
  config.kafka.delete(:'heartbeat.interval.ms')
end

DT[:c1_partitions] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:c1_partitions] << messages.metadata.partition
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 4)
    consumer Consumer
  end
end

4.times { |i| produce(DT.topic, "test#{i}", partition: i) }

thread = Thread.new do
  sleep(0.1) until DT[:c1_partitions].size >= 4

  # Start a second consumer that will join and cause rebalancing
  consumer = Rdkafka::Config.new(
    Karafka::Setup::AttributesMap.consumer(
      'bootstrap.servers': Karafka::App.config.kafka[:'bootstrap.servers'],
      'group.id': Karafka::App.consumer_groups.first.id,
      'group.protocol': 'consumer'
    )
  ).consumer

  consumer.subscribe(DT.topic)

  # Poll a few times to join the group and receive partition assignment
  10.times do
    message = consumer.poll(1_000)

    next unless message

    DT[:c2_got_messages] = true
    break
  end

  consumer.close
end

start_karafka_and_wait_until do
  # Wait until first consumer has processed from all 4 partitions initially
  # and second consumer has joined
  DT[:c1_partitions].size == 4 && DT[:c2_got_messages]
end

# First consumer should have received messages from all 4 partitions
# (initially it was the only consumer)
assert_equal [0, 1, 2, 3], DT[:c1_partitions].to_a.sort

thread.join
