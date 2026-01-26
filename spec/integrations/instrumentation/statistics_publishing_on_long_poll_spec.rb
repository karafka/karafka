# frozen_string_literal: true

# Karafka should publish statistics even when a long blocking processing occurs and there are no
# processing workers available as it should happen from one of the main threads.

setup_karafka do |config|
  config.concurrency = 1
  # Publish every one second to check if this is going to be as often within the time-frame of
  # the processing as expected
  config.kafka[:"statistics.interval.ms"] = 1_000
  config.internal.tick_interval = 1_000
  config.max_wait_time = 30_000
  config.shutdown_timeout = 35_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end
end

draw_routes(nil, create_topics: false) do
  topic DT.topic do
    consumer Consumer
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |_event|
  DT[:stats] << Time.now.to_f
end

Karafka::App.monitor.subscribe("connection.listener.fetch_loop.received") do |event|
  DT[:polls] << ((Time.now.to_f - (event[:time] / 1_000))..Time.now.to_f)
end

start_karafka_and_wait_until do
  sleep(30)
  true
end

in_polls = 0

DT[:polls].each do |poll|
  DT[:stats].each do |stat|
    in_polls += 1 if poll.include?(stat)
  end
end

assert DT[:stats].size >= 30
assert in_polls >= 28
