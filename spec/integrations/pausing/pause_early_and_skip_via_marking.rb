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
      DT[:messages] << message.offset
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:messages].size >= 1
end

consumer = setup_rdkafka_consumer

Thread.new do
  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:other] << message.offset
  end
end

def sum
  DT[:messages].size + DT[:other].size
end

sleep(0.1) until sum >= 20

20.times do |i|
  assert_equal i, (DT[:messages] + DT[:other])[i]
end

assert_equal 20, sum

consumer.close
