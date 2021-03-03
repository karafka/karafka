# frozen_string_literal: true

# Karafka should be able to start consuming from the latest offset

setup_karafka do |config|
  config.kafka['auto.offset.reset'] = 'latest'
end

before = Array.new(10) { SecureRandom.uuid }
after = Array.new(10) { SecureRandom.uuid }

# Sends some messages before starting Karafka - those should not be received
before.each { |number| produce(DataCollector.topic, number) }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[message.metadata.partition] << message.raw_payload
    end
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

# Start Karafka
Thread.new { Karafka::Server.run }

# Give it some time to boot and connect before dispatching messages
sleep(10)

# Dispatch the messages that should be consumed
after.each { |number| produce(DataCollector.topic, number) }

wait_until do
  DataCollector.data[0].size >= 10
end

assert_equal after, DataCollector.data[0]
assert_equal 1, DataCollector.data.size
