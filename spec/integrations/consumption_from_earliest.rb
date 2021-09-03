# frozen_string_literal: true

# Karafka should be able to easily consume all the messages from earliest (default)

setup_karafka

numbers = Array.new(100) { rand.to_s }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[message.metadata.partition] << message.raw_payload
    end
  end
end

Karafka::App.consumer_groups.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

numbers.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 100
end

assert_equal numbers, DataCollector.data[0]
assert_equal 1, DataCollector.data.size
