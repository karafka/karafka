# frozen_string_literal: true

# When user initiates a pause, the automatic offset management should not mark the last batch
# message as consumed automatically to prevent a scenario, where upon a rebalance during the pause
# the partition is gave away and processing starts now from the last offset prior to pause but
# from the automatic offset.

setup_karafka do |config|
  config.max_messages = 50
  config.pause_timeout = 2_000
  config.pause_max_timeout = 2_000
  config.pause_with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:paused] << messages.first.offset
    DT[:last] << messages.last.offset

    pause(messages.first.offset, 1_000)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
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
