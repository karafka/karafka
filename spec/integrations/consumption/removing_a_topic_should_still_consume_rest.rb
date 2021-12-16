# frozen_string_literal: true

# Karafka should be able to consume messages after a no-longer used topic has been removed from
# a given consumer group. It should not cause any problems

setup_karafka

elements1 = Array.new(10) { SecureRandom.uuid }
elements2 = Array.new(10) { SecureRandom.uuid }

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[0] << message.raw_payload
    end
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[1] << message.raw_payload
    end
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topics.first do
      consumer Consumer1
    end

    topic DataCollector.topics.last do
      consumer Consumer2
    end
  end
end

elements1.each { |data| produce(DataCollector.topics.first, data) }
elements2.each { |data| produce(DataCollector.topics.last, data) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 10 &&
    DataCollector.data[1].size >= 10
end

# Clear all the routes so later we can subscribe to only one topic
Karafka::App.routes.clear

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topics.last do
      consumer Consumer2
    end
  end
end

# We needed a new producer since Karafka closed the regular one when it stopped
producer = ::WaterDrop::Producer.new do |config|
  config.kafka = { 'bootstrap.servers' => '127.0.0.1:9092' }
end

# We publish again and we will check that only one topic got consumed afterwards
elements1.each do |data|
  producer.produce_sync(topic: DataCollector.topics.first, payload: data)
end

elements2.each do |data|
  producer.produce_sync(topic: DataCollector.topics.last, payload: data)
end

start_karafka_and_wait_until do
  DataCollector.data[1].size >= 20
end

# This topic should receive only data that was dispatched before we removed the topic from routes
assert_equal 10, DataCollector.data[0].size
# This should receive also the rest, since this topic remained in the consumer group
assert_equal 20, DataCollector.data[1].size
