# frozen_string_literal: true

# Taking the already fetched messages should not make a batch poll last noticeably longer than
# `max_wait_time`, both when the messages are prefetched and when they trickle in.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again. A background producer then keeps a steady low traffic going.

MAX_WAIT_TIME = 1_000
MESSAGES = 500

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_wait_time = MAX_WAIT_TIME
  config.max_messages = 10_000
end

Karafka.monitor.subscribe("connection.listener.fetch_loop.received") do |event|
  DT[:times] << event[:time]
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(MESSAGES))

Thread.new do
  20.times do
    produce(DT.topic, "1")
    sleep(0.2)
  end
end

start_karafka_and_wait_until do
  DT[:offsets].size >= MESSAGES + 20
end

assert_equal (0...(MESSAGES + 20)).to_a, DT[:offsets]
# Some batches wait for the trickling messages
assert DT[:times].count { |time| time >= MAX_WAIT_TIME - 100 } >= 1
assert(DT[:times].all? { |time| time < MAX_WAIT_TIME + 500 })
