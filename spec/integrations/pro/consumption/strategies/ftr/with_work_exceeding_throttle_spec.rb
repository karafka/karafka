# frozen_string_literal: true

# When doing work that is exceeding timeouts, we should not throttle. Instead we need to seek
# to the first throttled message and just move on.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end

    sleep(2)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    throttling(
      limit: 2,
      interval: 1_000
    )
  end
end

# This should never happen because throttle expires and we seek to the correct location
Karafka.monitor.subscribe 'filtering.throttled' do
  raise
end

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  # This needs to run for a while as on slow CIs things pick up slowly
  sleep(15)
end

# All messages should be received and seek should work correctly
assert_equal DT[0], (0...DT[0].size).to_a
