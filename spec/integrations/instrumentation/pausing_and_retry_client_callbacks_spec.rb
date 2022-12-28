# frozen_string_literal: true

# We should be able to get client level instrumentation on pausing and resuming

setup_karafka do |config|
  config.pause_timeout = 50
  config.pause_max_timeout = 50
end

class Consumer < Karafka::BaseConsumer
  def consume
    pause(messages.first.offset, 100)
  end
end

draw_routes(Consumer)

pause_events = []
resume_events = []

Karafka::App.monitor.subscribe('client.pause') do |event|
  pause_events << event
end

Karafka::App.monitor.subscribe('client.resume') do |event|
  resume_events << event
end

produce_many(DT.topic, DT.uuids(2))

start_karafka_and_wait_until do
  pause_events.size >= 1 && resume_events.size >= 1
end

pause_event = pause_events.last
resume_event = resume_events.last

assert_equal DT.topic, pause_event[:topic]
assert_equal 0, pause_event[:partition]
assert_equal 0, pause_event[:offset]

assert_equal DT.topic, resume_event[:topic]
assert_equal 0, resume_event[:partition]
