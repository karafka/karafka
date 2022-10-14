# frozen_string_literal: true

# When on one partition topic an error occurs, other topics should be processed and given
# partition should catch up on recovery after the pause timeout

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
  # We sleep more to check if when sleeping other topic messages are processed
  config.pause_timeout = 5_000
  config.pause_max_timeout = 5_000
  config.pause_with_exponential_backoff = false
end

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

class Consumer1 < Karafka::BaseConsumer
  def consume
    @count ||= 0
    @count += 1

    raise StandardError if @count < 3

    messages.each do |message|
      DT[0] << message.raw_payload
      DT[:all] << message.raw_payload
    end

    DT[1] << Thread.current.object_id
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[2] << message.raw_payload
      DT[:all] << message.raw_payload
    end

    DT[3] << Thread.current.object_id
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topics.first do
      consumer Consumer1
    end

    topic DT.topics.last do
      consumer Consumer2
    end
  end
end

elements1 = DT.uuids(10)
elements2 = DT.uuids(10)

elements1.each { |data| produce(DT.topics.first, data) }
# We send one message so the topic gets created
elements2[0...1].each { |data| produce(DT.topics.last, data) }

Thread.new do
  # Dispatching those after 2s will ensure we start sending when the first partition is paused
  sleep(2)
  elements2[1..].each { |data| produce(DT.topics.last, data) }
end

start_karafka_and_wait_until do
  DT[:all].size >= 20
end

assert DT[0].size >= 10
assert DT[:errors].size == 2
assert_equal 1, DT[1].uniq.size
assert_equal 1, DT[3].uniq.size
assert_equal StandardError, DT[:errors].first[:error].class
assert_equal 'consumer.consume.error', DT[:errors].first[:type]
assert_equal 'error.occurred', DT[:errors].first.id
assert_equal 10, DT[0].uniq.size
assert_equal 10, DT[2].uniq.size
# Same worker from the same thread should process both
assert_equal DT[1].uniq, DT[3].uniq
assert_equal 20, DT[:all].size
assert_equal elements2, DT[:all][0..9]
