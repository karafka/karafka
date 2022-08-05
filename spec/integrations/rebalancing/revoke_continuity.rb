# frozen_string_literal: true

# When Karafka looses a given partition but later gets it back, it should pick it up from the last
# offset committed without any problems

setup_karafka do |config|
  config.concurrency = 4
end

create_topic(partitions: 2)

class Consumer < Karafka::BaseConsumer
  def consume
    partition = messages.metadata.partition

    messages.each do |message|
      # We store offsets only until revoked
      return unless mark_as_consumed!(message)

      DT[partition] << message.offset
    end

    return if @marked

    # For partition we have lost this will run twice
    DT[:partitions] << partition
    @marked = true
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

Thread.new do
  loop do
    2.times do
      produce(DT.topic, '1', partition: 0)
      produce(DT.topic, '1', partition: 1)
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

  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:jumped] << message
    consumer.store_offset(message)
    break
  end

  consumer.commit(nil, false)

  consumer.close
end

start_karafka_and_wait_until do
  other.join && DT[:partitions].size >= 3
end

revoked_partition = DT[:jumped].first.partition
jumped_offset = DT[:jumped].first.offset

assert_equal 1, DT[:jumped].size

# This single one should have been consumed by a different process
assert_equal false, DT.data[revoked_partition].include?(jumped_offset)

# We should have all the others in proper order and without any other missing
previous = nil

DT.data[revoked_partition].each do |offset|
  unless previous
    previous = offset
    next
  end

  previous = jumped_offset if previous + 1 == jumped_offset

  assert_equal previous + 1, offset

  previous = offset
end
