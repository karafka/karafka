# frozen_string_literal: true

# Karafka should be able to consume many topics with different initial offset strategies and should
# handle that correctly for all the topics in many groups

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer1 < Karafka::BaseConsumer
  def consume
    DataCollector[0] << messages.first.raw_payload
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DataCollector[1] << messages.first.raw_payload
  end
end

draw_routes do
  consumer_group DataCollector.consumer_groups.first do
    topic DataCollector.topics.first do
      consumer Consumer1
      initial_offset 'earliest'
    end
  end

  consumer_group DataCollector.consumer_groups.last do
    topic DataCollector.topics.last do
      consumer Consumer2
      initial_offset 'latest'
    end
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
assert_equal '0', DataCollector[0].first
assert_equal 1, DataCollector[0].size
assert_equal '1', DataCollector[1].first
assert_equal 1, DataCollector[1].size
