# frozen_string_literal: true

# Karafka should be able to consume same topic using two consumer groups

setup_karafka

topic1 = DataCollector.topics[0]
topic2 = DataCollector.topics[1]
topic1_data = Array.new(10) { { rand.to_s => rand.to_s } }
topic2_data = Array.new(10) { { rand.to_s => rand.to_s } }

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[topic.name] << message.payload
    end
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[topic.name] << message.payload
    end
  end
end

Karafka::App.consumer_groups.draw do
  consumer_group DataCollector.consumer_group do
    topic topic1 do
      consumer Consumer1
    end

    topic topic2 do
      consumer Consumer2
    end
  end
end

topic1_data.each { |data| produce(topic1, data.to_json) }
topic2_data.each { |data| produce(topic2, data.to_json) }

start_karafka_and_wait_until do
  DataCollector.data.values.flatten.size >= 20
end

assert_equal DataCollector.data[topic1], topic1_data
assert_equal DataCollector.data[topic2], topic2_data
assert_equal DataCollector.data.size, 2
