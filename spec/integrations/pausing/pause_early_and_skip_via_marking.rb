# frozen_string_literal: true

# We should be able to pause the partition and still mark messages as consumed
# When another process would pick up the work, it should start from the last consumption marked

setup_karafka do |config|
  config.max_messages = 5
  config.pause_timeout = 10_000
  config.pause_max_timeout = 10_000
  config.pause_with_exponential_backoff = false
  config.manual_offset_management = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if @paused

    @paused = true
    # Pause on our first message
    pause(messages.first.offset)
    # And then skip via seek
    mark_as_consumed(messages.last)

    messages.each do |message|
      DataCollector[:messages] << message.offset
    end
  end
end

draw_routes(Consumer)

20.times { |i| produce(DataCollector.topic, i.to_s) }

start_karafka_and_wait_until do
  DataCollector[:messages].size >= 1
end

consumer = setup_rdkafka_consumer

Thread.new do
  consumer.subscribe(DataCollector.topic)

  consumer.each do |message|
    DataCollector[:other] << message.offset
  end
end

def sum
  DataCollector[:messages].size + DataCollector[:other].size
end

sleep(0.1) until sum >= 20

20.times do |i|
  assert_equal i, (DataCollector[:messages] + DataCollector[:other])[i]
end

assert_equal 20, sum
