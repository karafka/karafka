# frozen_string_literal: true

# Important: this may not work as expected for a manual pause case. Please read the below message.
#
# When we pause a partition without providing the timeout, it should use the timeout defined
# in the retry settings. The case here is, that when processing is successful we reset the pause
# counter, so the retry is never acknowledged (like it is for cases with errors). This means that
# manual pausing will never use the automatic exponential backoff.

setup_karafka do |config|
  config.max_messages = 1
  config.pause_timeout = 2_000
  config.pause_max_timeout = 10_000
  config.pause_with_exponential_backoff = true
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
  assert (time - previous) * 1_000 <= 4_000

  previous = time
end
