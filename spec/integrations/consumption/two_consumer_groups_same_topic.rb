# frozen_string_literal: true

# Karafka should be able to consume same topic using two consumer groups

setup_karafka

jsons = Array.new(100) { { SecureRandom.uuid => rand.to_s } }

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
    topic DataCollector.topic do
      consumer Consumer
    end
  end

  consumer_group DataCollector.consumer_groups.last do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

jsons.each { |data| produce(DataCollector.topic, data.to_json) }

start_karafka_and_wait_until do
  DataCollector.data.values.flatten.size >= 200
end

keys = DataCollector.data.keys

assert_equal 2, DataCollector.data.size
assert_equal 100, DataCollector.data[keys[0]].size
assert_equal 100, DataCollector.data[keys[1]].size
assert_equal jsons, DataCollector.data[keys[0]]
assert_equal jsons, DataCollector.data[keys[1]]
