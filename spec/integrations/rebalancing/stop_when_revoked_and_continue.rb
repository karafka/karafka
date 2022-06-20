# frozen_string_literal: true

# When given partition was revoked, we should be able to stop processing and it should not affect
# other consumers from consuming.

# On the other hand, when we get back what we have lost, we should be able to get going and we
# should not have to process what was processed by others.

TOPIC = 'integrations_12_02'

setup_karafka do |config|
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    partition = messages.metadata.partition

    messages.each do |message|
      return unless mark_as_consumed!(message)

      DataCollector[partition] << message.offset
    end

    return if @marked

    # For partition we have lost this will run twice
    DataCollector[:partitions] << partition
    @marked = true
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
    consumer.store_offset(message)
    break
  end

  consumer.commit(nil, false)

  consumer.close
end

start_karafka_and_wait_until do
  DataCollector[:partitions].size >= 3
end

other.join

revoked_partition = DataCollector[:jumped].first.partition
jumped_offset = DataCollector[:jumped].first.offset

assert_equal 1, DataCollector[:jumped].size

# This single one should have been consumed by a different process
assert_equal false, DataCollector.data[revoked_partition].include?(jumped_offset)

# We should have all the others in proper order and without any other missing
previous = nil

DataCollector.data[revoked_partition].each do |offset|
  unless previous
    previous = offset
    next
  end

  previous = jumped_offset if previous + 1 == jumped_offset

  assert_equal previous + 1, offset

  previous = offset
end
