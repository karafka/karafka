# frozen_string_literal: true

# When one partition is paused by us manually, we should be consuming others without interruption.
#
# Here we check, that the paused partition data is consumed as last (since we pause long enough)
# and that the other partition's data was consumed first.

TOPIC = 'integrations_02_02'

setup_karafka do |config|
  # We set it to 1 as in case of not pausing as expected with one worker the job would stop all
  # processing and we would fail.
  config.concurrency = 1
  config.max_messages = 10
  config.initial_offset = 'latest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    if messages.metadata.partition.zero?
      DataCollector[:ticks] << true
      pause(messages.first.offset, 500)

      return
    end

    sleep(0.5)

    messages.each do |message|
      DataCollector[:partitions] << message.partition
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    # Special topic with 2 partitions available
    topic TOPIC do
      consumer Consumer
    end
  end
end

draw_routes(Consumer)

Thread.new do
  sleep(5)

  sleep(0.1) while DataCollector[:running].empty?

  100.times do
    2.times do |partition|
      produce(TOPIC, SecureRandom.uuid, partition: partition)
    end
  end
end

start_karafka_and_wait_until do
  DataCollector[:running] << true
  DataCollector[:partitions].size >= 100
end

assert_equal [1], DataCollector[:partitions].uniq
assert DataCollector[:ticks].count > 1
