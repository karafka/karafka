# frozen_string_literal: true

# Karafka should use more than one thread to consume independent topics partitions

setup_karafka do |config|
  config.concurrency = 10
  config.kafka['auto.offset.reset'] = 'latest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    # This will simulate, that the thread is busy in a bit random way, so more worker threads can
    # be occupied
    sleep(1)

    messages.each do |message|
      DataCollector.data[message.partition] << Thread.current.object_id
    end
  end

  def on_shutdown
    mark_as_consumed!(messages.last)
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    # Special topic with 10 partitions available
    topic 'integrations_1_10' do
      consumer Consumer
    end
  end
end

# Start Karafka
Thread.new { Karafka::Server.run }

# Give it some time to boot and connect before dispatching messages
sleep(5)

# We send only one message to each topic partition, so when messages are consumed, it forces them
# to be in separate worker threads
10.times { |i| produce('integrations_1_10', SecureRandom.uuid, partition: i) }

wait_until do
  DataCollector.data.values.flatten.size >= 10
end

# 10 partitions are expected
assert_equal 10, DataCollector.data.size
# In 10 threads due to sleep
assert_equal 10, DataCollector.data.values.flatten.uniq.count
