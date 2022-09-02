# frozen_string_literal: true

# Karafka should replace coordinator for consumer of a given topic partition after partition was
# taken away from us and assigned back

setup_karafka do |config|
  config.concurrency = 4
  config.license.token = pro_license_token
end

create_topic(partitions: 2)

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    partition = messages.metadata.partition

    DT[partition] << coordinator.object_id
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      virtual_partitioner ->(_) { rand }
    end
  end
end

Thread.new do
  loop do
    produce_many(DT.topic, DT.uuids(2), partition: 0)
    produce_many(DT.topic, DT.uuids(2), partition: 1)

    sleep(0.5)
  rescue StandardError
    nil
  end
end

# We need a second producer to trigger a rebalance
consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:jumped] << message.partition
    sleep 10
    consumer.store_offset(message)
    break
  end

  consumer.commit(nil, false)

  consumer.close
end

start_karafka_and_wait_until do
  other.join &&
    (
      DT[0].uniq.size >= 3 ||
        DT[1].uniq.size >= 3
    )
end

taken_partition = DT[:jumped].first
non_taken = taken_partition == 1 ? 0 : 1

assert_equal 2, DT.data[taken_partition].uniq.size
assert_equal 3, DT.data[non_taken].uniq.size
