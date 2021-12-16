# frozen_string_literal: true

# Karafka should not return more messages than defined with `max_messages`

setup_karafka

elements = Array.new(20) { SecureRandom.uuid }

elements.each { |data| produce(DataCollector.topic, data) }

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[:counts] << messages.size
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      max_messages 5
      max_wait_time 10_000
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  DataCollector.data[:counts].size >= 4
end

assert_equal [5], DataCollector.data[:counts].uniq
assert_equal 4, DataCollector.data[:counts].size
