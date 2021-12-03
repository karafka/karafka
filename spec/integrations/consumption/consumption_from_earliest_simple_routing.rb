# frozen_string_literal: true

ROOT_PATH = Pathname.new(File.expand_path(File.join(File.dirname(__FILE__), '../../../')))
require ROOT_PATH.join('spec/integrations_helper.rb')

# Karafka should be able to easily consume all the messages from earliest (default) when
# simple routing is in use

setup_karafka

elements = Array.new(10) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[message.metadata.partition] << message.raw_payload
    end
  end
end

Karafka::App.routes.draw do
  topic DataCollector.topic do
    consumer Consumer
  end
end

elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 10
end

assert_equal elements, DataCollector.data[0]
assert_equal 1, DataCollector.data.size
