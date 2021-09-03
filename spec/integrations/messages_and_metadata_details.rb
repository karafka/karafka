# frozen_string_literal: true

# Karafka messages data should be as defined here

setup_karafka

numbers = Array.new(10) { rand.to_s }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[message.metadata.partition] << message
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

numbers.each { |number| produce(DataCollector.topic, number) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 10
end

DataCollector.data[0].each_with_index do |message, index|
  assert_equal message.class, Karafka::Messages::Message
  assert_equal message.metadata.class, Karafka::Messages::Metadata
  assert_equal message.raw_payload.class, String
  assert_equal message.received_at.class, Time
  assert_equal message.metadata.received_at.class, Time
  assert_equal message.partition, 0
  assert_equal message.timestamp.class, Time
  assert_equal message.offset, index
  assert_equal message.topic, DataCollector.topic
  assert_equal message.headers, {}
  assert_equal message.key, nil
  assert_equal message.deserialized?, false
end
