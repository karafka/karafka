# frozen_string_literal: true

# Karafka should be able to consume many topics with different initial offset strategies and should
# handle that correctly for all the topics

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer1 < Karafka::BaseConsumer
  def consume
    DT[0] << messages.first.raw_payload
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DT[1] << messages.first.raw_payload
  end
end

draw_routes do
  topic DT.topics.first do
    consumer Consumer1
    initial_offset 'earliest'
  end

  topic DT.topics.last do
    consumer Consumer2
    initial_offset 'latest'
  end
end

produce(DT.topics.first, '0')
# This one should not be picked at all because it is sent before we start listening for the
# first time
produce(DT.topics.last, '0')

Thread.new do
  loop do
    sleep(10)
    produce(DT.topics.last, '1')
  rescue WaterDrop::Errors::ProducerClosedError
    break
  end
end

start_karafka_and_wait_until do
  DT.data.values.flatten.size >= 2
end

assert_equal 2, DT.data.keys.size
assert_equal '0', DT[0].first
assert_equal 1, DT[0].size
assert_equal '1', DT[1].first
assert_equal 1, DT[1].size
