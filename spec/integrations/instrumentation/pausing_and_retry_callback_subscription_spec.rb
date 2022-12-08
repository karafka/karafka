# frozen_string_literal: true

# We should be able to instrument on pausing and retry events

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.pause_timeout = 50
  config.pause_max_timeout = 50
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless @auto
      @auto = true

      raise
    end

    pause(messages.first.offset, 100)
  end
end

draw_routes(Consumer)

pause_events = []
retry_events = []

Karafka::App.monitor.subscribe('consumer.consuming.pause') do |event|
  pause_events << event
end

Karafka::App.monitor.subscribe('consumer.consuming.retry') do |event|
  retry_events << event
end

produce_many(DT.topic, DT.uuids(2))

start_karafka_and_wait_until do
  pause_events.size >= 2 && retry_events.size >= 1
end

auto_event = pause_events.first
manual_event = pause_events.last
retry_event = retry_events.first

assert_equal false, auto_event[:manual]
assert_equal DT.topic, auto_event[:topic]
assert_equal 0, auto_event[:partition]
assert_equal 0, auto_event[:offset]
assert_equal 50, auto_event[:timeout], auto_event[:timeout]
assert_equal 1, auto_event[:attempt], auto_event[:attempt]

assert_equal true, manual_event[:manual], manual_event[:manual]
assert_equal DT.topic, manual_event[:topic]
assert_equal 0, manual_event[:partition]
assert_equal 0, manual_event[:offset]
assert_equal 100, manual_event[:timeout], manual_event[:timeout]
assert_equal 2, manual_event[:attempt], manual_event[:attempt]

assert_equal false, retry_event.payload.key?(:manual)
assert_equal DT.topic, retry_event[:topic]
assert_equal 0, retry_event[:partition]
assert_equal 0, retry_event[:offset]
assert_equal 50, retry_event[:timeout], retry_event[:timeout]
assert_equal 1, retry_event[:attempt], retry_event[:attempt]
