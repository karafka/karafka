# frozen_string_literal: true

# Karafka should be able to deserialize JSON messages

ROOT_PATH = Pathname.new(File.expand_path(File.join(File.dirname(__FILE__), '../../')))
require ROOT_PATH.join('spec/integrations_helper.rb')

setup_karafka

jsons = Array.new(100) { { SecureRandom.uuid => rand.to_s } }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[message.metadata.partition] << message.payload
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

jsons.each { |data| produce(DataCollector.topic, data.to_json) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 100
end

assert_equal jsons, DataCollector.data[0]
assert_equal 1, DataCollector.data.size
