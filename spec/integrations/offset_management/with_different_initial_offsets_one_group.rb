# frozen_string_literal: true

# Karafka should be able to consume many topics with different initial offset strategies and should
# handle that correctly for all the topics

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer1 < Karafka::BaseConsumer
  def consume
    DataCollector.data[0] << messages.first.raw_payload
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DataCollector.data[1] << messages.first.raw_payload
  end
end

draw_routes do
  topic DataCollector.topics.first do
    consumer Consumer1
    initial_offset 'earliest'
  end

  topic DataCollector.topics.last do
    consumer Consumer2
    initial_offset 'latest'
  end
end

produce(DataCollector.topics.first, '0')
# This one should not be picked at all because it is sent before we start listening for the
# first time
produce(DataCollector.topics.last, '0')

Thread.new do
  sleep(10)
  produce(DataCollector.topics.last, '1')
end

start_karafka_and_wait_until do
  DataCollector.data.values.flatten.size >= 2
end

assert_equal 2, DataCollector.data.keys.size
assert_equal '0', DataCollector.data[0].first
assert_equal 1, DataCollector.data[0].size
assert_equal '1', DataCollector.data[1].first
assert_equal 1, DataCollector.data[1].size
