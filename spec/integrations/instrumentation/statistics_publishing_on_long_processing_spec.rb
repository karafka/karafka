# frozen_string_literal: true

# Karafka should publish statistics even when a long blocking processing occurs and there are no
# processing workers available as it should happen from one of the main threads.

setup_karafka do |config|
  config.concurrency = 1
  # Publish every one second to check if this is going to be as often within the time-frame of
  # the processing as expected
  config.kafka[:'statistics.interval.ms'] = 1_000
  config.internal.tick_interval = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:start] = Time.now.to_f
    sleep(15)
    DT[:stop] = Time.now.to_f
  end
end

draw_routes(nil, create_topics: false) do
  topic DT.topic do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(1))

Karafka::App.monitor.subscribe('statistics.emitted') do |_event|
  DT[:stats] << Time.now.to_f
end

start_karafka_and_wait_until do
  DT.key?(:stop)
end

range = DT[:start]..DT[:stop]

in_between = DT[:stats].select { |time| range.include?(time) }.size

# It should be in between 14 and 16 as we have 15 seconds and we tick every second
assert in_between >= 14
assert in_between <= 16
