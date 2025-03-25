# frozen_string_literal: true

# Even if we are in a long active pause, a short pause should overwrite the long one

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:tick] << true
    pause(messages.first.offset, 100_000_000)
    sleep(2)
    pause(messages.first.offset, 1_000)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DT[:tick].size >= 2
end

# Just a precaution. If the long pause would supersede the short, it would never finish and timeout
assert (Time.now.to_f - started_at) < 30
