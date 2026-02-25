# frozen_string_literal: true

# When partition is paused for a longer period of time, its metadata won't be refreshed.
# This means that consumer-reported statistics lag will be frozen.
# This spec illustrates that.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
end

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed!(messages.last)

    unless DT.key?(:done)
      # Pause forever
      pause(messages.last.offset, 1_000_000)
      DT[:done] = true
    end
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  event.payload[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:lags] << partition_values["consumer_lag"]
    end
  end
end

produce_many(DT.topic, DT.uuids(1))

Thread.new do
  sleep(0.1) until DT.key?(:done)

  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(0.5)

    break if DT[:lags].size >= 20
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  DT[:lags].size >= 25
end

assert DT[:lags].max <= 2
