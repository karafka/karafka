# frozen_string_literal: true

# When we received messages, on_shutdown should kick in for every consumer that did any work

ROOT_PATH = Pathname.new(File.expand_path(File.join(File.dirname(__FILE__), '../../')))
require ROOT_PATH.join('spec/integrations_helper.rb')

setup_karafka

topic1 = DataCollector.topics[0]
topic2 = DataCollector.topics[1]
topic3 = DataCollector.topics[2]

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[0] << 1
  end

  def on_shutdown
    DataCollector.data[topic.name] << object_id
  end
end

Karafka::App.consumer_groups.draw do
  consumer_group DataCollector.consumer_group do
    topic topic1 do
      consumer Consumer
    end

    topic topic2 do
      consumer Consumer
    end

    # This one will do nothing
    topic topic3 do
      consumer Consumer
    end
  end
end

produce(topic1, '1')
produce(topic2, '1')

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 2
end

assert_equal 1, DataCollector.data[topic1].size
assert_equal 1, DataCollector.data[topic2].size
assert_equal 0, DataCollector.data[topic3].size
assert_not_equal DataCollector.data[topic1].first, DataCollector.data[topic2].first
