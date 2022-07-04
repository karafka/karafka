# frozen_string_literal: true

# Karafka should replace coordinator for consumer of a given topic partition after partition was
# taken away from us and assigned back

TOPIC = 'integrations_14_02'

setup_karafka do |config|
  config.concurrency = 4
  config.license.token = pro_license_token
end

class Consumer < Karafka::BaseConsumer
  def consume
    partition = messages.metadata.partition

    DataCollector[partition] << coordinator.object_id
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic TOPIC do
      consumer Consumer
    end
  end
end

Thread.new do
  loop do
    2.times do
      produce(TOPIC, '1', partition: 0)
      produce(TOPIC, '1', partition: 1)
    end

    sleep(0.5)
  rescue StandardError
    nil
  end
end

# We need a second producer to trigger a rebalance
consumer = setup_rdkafka_consumer

other = Thread.new do
  sleep(10)

  consumer.subscribe(TOPIC)

  consumer.each do |message|
    DataCollector[:jumped] << message
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
      DataCollector[0].uniq.size >= 3 ||
        DataCollector[1].uniq.size >= 3
    )
end

taken_partition = DataCollector[:jumped].first.partition
non_taken = taken_partition == 1 ? 0 : 1

assert_equal 2, DataCollector.data[taken_partition].uniq.size
assert_equal 3, DataCollector.data[non_taken].uniq.size
