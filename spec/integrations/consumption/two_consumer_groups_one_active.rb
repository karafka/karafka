# frozen_string_literal: true

# Karafka should be able to consume one topic when two consumer groups are defined but only one
# is active

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      group = topic.consumer_group.name
      DataCollector.data[group] << message.payload
    end
  end
end

draw_routes do
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

jsons = Array.new(10) { { SecureRandom.uuid => rand.to_s } }

# We send same messages to both topics, but except only one to run and consume
jsons.each do |data|
  produce(DataCollector.topics.first, data.to_json)
  produce(DataCollector.topics.last, data.to_json)
end

start_karafka_and_wait_until do
  DataCollector.data.values.flatten.size >= 10
end

keys = DataCollector.data.keys

assert_equal jsons, DataCollector.data[keys[0]]
assert_equal 1, DataCollector.data.size
