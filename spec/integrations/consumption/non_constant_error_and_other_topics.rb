# frozen_string_literal: true

# When on one partition topic an error occurs, other topics should be processed and given
# partition should catch up on recovery after the pause timeout

setup_karafka do |config|
  config.concurrency = 1
  # We sleep more to check if when sleeping other topic messages are processed
  config.pause_timeout = 5_000
  config.pause_max_timeout = 5_000
  config.pause_with_exponential_backoff = false
end

class Listener
  def on_error_occurred(event)
    DataCollector[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

class Consumer1 < Karafka::BaseConsumer
  def consume
    @count ||= 0
    @count += 1

    raise StandardError if @count < 3

    messages.each do |message|
      DataCollector[0] << message.raw_payload
      DataCollector[:all] << message.raw_payload
    end

    DataCollector[1] << Thread.current.object_id
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector[2] << message.raw_payload
      DataCollector[:all] << message.raw_payload
    end

    DataCollector[3] << Thread.current.object_id
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

elements1 = Array.new(10) { SecureRandom.uuid }
elements2 = Array.new(10) { SecureRandom.uuid }

elements1.each { |data| produce(DataCollector.topics.first, data) }
# We send one message so the topic gets created
elements2[0...1].each { |data| produce(DataCollector.topics.last, data) }

Thread.new do
  # Dispatching those after 2s will ensure we start sending when the first partition is paused
  sleep(2)
  elements2[1..].each { |data| produce(DataCollector.topics.last, data) }
end

start_karafka_and_wait_until do
  DataCollector[:all].size >= 20
end

assert DataCollector[0].size >= 10
assert DataCollector[:errors].size == 2
assert_equal 1, DataCollector[1].uniq.size
assert_equal 1, DataCollector[3].uniq.size
assert_equal StandardError, DataCollector[:errors].first[:error].class
assert_equal 'consumer.consume.error', DataCollector[:errors].first[:type]
assert_equal 'error.occurred', DataCollector[:errors].first.id
assert_equal 10, DataCollector[0].uniq.size
assert_equal 10, DataCollector[2].uniq.size
# Same worker from the same thread should process both
assert_equal DataCollector[1].uniq, DataCollector[3].uniq
assert_equal 20, DataCollector[:all].size
assert_equal elements2, DataCollector[:all][0..9]
