# frozen_string_literal: true

ROOT_PATH = Pathname.new(File.expand_path(File.join(File.dirname(__FILE__), '../../')))
require ROOT_PATH.join('spec/integrations_helper.rb')

# Karafka should be able to work with messages that have headers

setup_karafka

elements = Array.new(10) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[0] << [message.raw_payload, message.headers]
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

elements.each { |data| produce(DataCollector.topic, data, headers: { 'value' => data }) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 10
end

assert_equal 1, DataCollector.data.size
assert_equal 10, DataCollector.data[0].size

DataCollector.data[0].each do |element|
  assert_equal element[0], element[1].fetch('value')
end
