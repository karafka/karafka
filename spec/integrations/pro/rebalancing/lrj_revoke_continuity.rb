# frozen_string_literal: true

# When Karafka looses a given partition but later gets it back, it should pick it up from the last
# offset committed without any problems

TOPIC = 'integrations_9_02'

setup_karafka do |config|
  config.license.token = pro_license_token
  # We need 4: two partitions processing and non-blocking revokes
  config.concurrency = 4
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    partition = messages.metadata.partition

    messages.each do |message|
      # We store offsets only until revoked
      return unless mark_as_consumed!(message)
      DataCollector[partition] << message.offset
    end

    # For partition we have lost this will run twice
    unless @marked
      DataCollector[:partitions] << partition
      @marked = true
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic TOPIC do
      consumer Consumer
      long_running_job true
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
  rescue
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
    previous == offset
    next
  end

  if offset == jumped_offset
    previous = jumped_offset
    next
  end

  assert previous + 1 == offset
end
