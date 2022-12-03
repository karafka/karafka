# frozen_string_literal: true

# Karafka should not resume when manual pause is in use for LRJ

setup_karafka do |config|
  config.max_messages = 50
  config.pause_timeout = 2_000
  config.pause_max_timeout = 2_000
  config.pause_with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if messages.count < 2

    DT[:paused] << messages.first.offset
    DT[:last] << messages.last.offset

    pause(messages.first.offset, 1_000)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(200))

start_karafka_and_wait_until do
  DT[:paused].size >= 3
end

consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topic)

consumer.each do |message|
  DT[:jumped] << message.offset
  break
end

consumer.close

assert_equal DT[:jumped].last, DT[:paused].last
