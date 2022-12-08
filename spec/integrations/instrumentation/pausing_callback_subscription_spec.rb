# frozen_string_literal: true

# We should be able to instrument on pausing events

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

Karafka::App.monitor.subscribe('consumer.consuming.pause') do |event|
  pause_events << event
end

produce_many(DT.topic, DT.uuids(2))

start_karafka_and_wait_until do
  pause_events.size >= 2
end

auto = pause_events.first
manual = pause_events.last

assert_equal false, auto[:manual]
assert_equal DT.topic, auto[:topic]
assert_equal 0, auto[:partition]
assert_equal 0, auto[:offset]
assert_equal 50, auto[:timeout], auto[:timeout]
assert_equal 1, auto[:attempt], auto[:attempt]

assert_equal true, manual[:manual], manual[:manual]
assert_equal DT.topic, manual[:topic]
assert_equal 0, manual[:partition]
assert_equal 0, manual[:offset]
assert_equal 100, manual[:timeout], manual[:timeout]
assert_equal 2, manual[:attempt], manual[:attempt]
