# frozen_string_literal: true

# When using multiple consumer groups and when one is rebalanced, it should not affect the one
# that was not a rebalance subject

setup_karafka do |config|
  config.concurrency = 5
end

create_topic(name: DT.topics[0], partitions: 2)
create_topic(name: DT.topics[1], partitions: 2)

Thread.new do
  loop do
    2.times do |i|
      produce(DT.topics[i], '1', partition: 0)
      produce(DT.topics[i], '2', partition: 1)
    end

    sleep(1)
  end
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def on_revoked
    DT[messages.metadata.topic] << messages.metadata.partition
  end
end

draw_routes do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  consumer_group DT.consumer_groups[1] do
    topic DT.topics[1] do
      consumer Consumer
    end
  end
end

consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(10)
  consumer.subscribe(DT.topics[0])

  consumer.each { break }

  consumer.close
end

start_karafka_and_wait_until do
  other.join

  true
end

# The second topic should not be rebalanced at all as it is in a different consumer group than
# the one that had a rebalance
assert !DT.data.key?(DT.topics[1])
