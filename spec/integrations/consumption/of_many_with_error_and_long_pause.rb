# frozen_string_literal: true

# Karafka should pause and if pausing spans across batches, it should work and wait

setup_karafka do |config|
  # 60 seconds, long enough for it to not restart upon us finishing
  config.pause_timeout = 60 * 1_000
  config.pause_max_timeout = 60 * 1_000
  config.max_messages = 1
end

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do
      DataCollector.data[0] << object_id
    end

    raise StandardError
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do
      DataCollector.data[1] << object_id
    end
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topics.first do
      consumer Consumer1
    end

    topic DataCollector.topics.last do
      consumer Consumer2
    end
  end
end

elements = Array.new(5) { SecureRandom.uuid }

elements.each do |data|
  produce(DataCollector.topics.first, data)
  produce(DataCollector.topics.last, data)
end

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 1 &&
    DataCollector.data[1].size >= 5
end

assert_equal 1, DataCollector.data[0].size
assert_equal 5, DataCollector.data[1].size
assert_equal 1, DataCollector.data[1].uniq.size
