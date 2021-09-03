# frozen_string_literal: true

# Karafka should be able to consume same topic using two consumer groups

ROOT_PATH = Pathname.new(File.expand_path(File.join(File.dirname(__FILE__), '../../')))
require ROOT_PATH.join('spec/integrations_helper.rb')

setup_karafka

jsons = Array.new(100) { { rand.to_s => rand.to_s } }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      group = topic.consumer_group.name
      DataCollector.data[group] << message.payload
    end
  end
end

Karafka::App.consumer_groups.draw do
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

assert_equal jsons, DataCollector.data[keys[0]]
assert_equal jsons, DataCollector.data[keys[1]]
assert_equal 2, DataCollector.data.size
