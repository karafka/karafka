# frozen_string_literal: true

# On a low traffic topic, a message that arrives early in a long poll window should get a
# `received_at` close to the moment it was polled, not the moment the whole batch was built.

setup_karafka do |config|
  config.max_messages = 100
  config.max_wait_time = 5_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:lags] << (message.received_at - message.timestamp)
    end
  end
end

draw_routes(Consumer)

Karafka.monitor.subscribe("rebalance.partitions_assigned") { DT[:assigned] << true }

Thread.new do
  sleep(0.1) until DT[:assigned].any?
  # Let the consumer go idle in its long poll window before each message arrives
  sleep(1)
  produce(DT.topic, "1")
  sleep(2)
  produce(DT.topic, "2")
end

start_karafka_and_wait_until do
  DT[:lags].size >= 2
end

assert DT[:lags].max < 1, DT[:lags]
