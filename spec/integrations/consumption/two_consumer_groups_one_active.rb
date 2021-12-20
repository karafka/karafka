# frozen_string_literal: true

# Karafka should be able to consume one topic when two consumer groups are defined but only one
# is active

setup_karafka

jsons = Array.new(10) { { SecureRandom.uuid => rand.to_s } }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      group = topic.consumer_group.name
      DataCollector.data[group] << message.payload
    end
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_groups.first do
    topic DataCollector.topics.first do
      consumer Consumer
    end
  end

  consumer_group DataCollector.consumer_groups.last do
    topic DataCollector.topics.last do
      consumer Consumer
    end
  end
end

# Listen only on one consumer group
Karafka::Server.consumer_groups = [DataCollector.consumer_groups.first]

jsons.each { |data| produce(DataCollector.topics.first, data.to_json) }
jsons.each { |data| produce(DataCollector.topics.last, data.to_json) }

start_karafka_and_wait_until do
  DataCollector.data.values.flatten.size >= 10
end

keys = DataCollector.data.keys

assert_equal jsons, DataCollector.data[keys[0]]
assert_equal 1, DataCollector.data.size
