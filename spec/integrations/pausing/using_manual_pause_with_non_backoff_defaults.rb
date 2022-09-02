# frozen_string_literal: true

# When we pause a partition without providing the timeout, it should use the timeout defined
# in the retry settings

setup_karafka do |config|
  config.max_messages = 1
  config.pause_timeout = 2_000
  config.pause_max_timeout = 2_000
  config.pause_with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    pause(messages.last.offset + 1)

    DT[:pauses] << Time.now
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:pauses].size >= 5
end

previous = nil

assert_equal 5, DT[:pauses].count

previous = nil

DT[:pauses].each do |time|
  unless previous
    previous = time
    next
  end

  assert (time - previous) * 1_000 >= 2_000

  previous = time
end
