# frozen_string_literal: true

# We should be able to prolong a manual pause that we did pause already and the times should add up

setup_karafka do |config|
  config.max_messages = 5
  config.pause_timeout = 2_000
  config.pause_max_timeout = 2_000
  config.pause_with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:times] << Time.now.to_f

    pause(messages.last.offset + 1)

    sleep(1)

    pause(messages.last.offset + 1)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:times].size >= 4
end

# If second pausing would not work, it would be less than 3
time1 = DT[:times][1] - DT[:times][0]
time2 = DT[:times][3] - DT[:times][2]

assert time1 >= 3, "#{time1} expected to be equal or more than 3 seconds"
assert time2 >= 3, "#{time2} expected to be equal or more than 3 seconds"
