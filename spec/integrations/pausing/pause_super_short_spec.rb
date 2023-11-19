# frozen_string_literal: true

# When we pause for a time shorter than processing time, we should un-pause prior to the next poll
# We should not exceed two polls. First (before which we resume) may not get the data because
# after resuming we may not have enough time to start polling the given partition again.

setup_karafka do |config|
  config.max_messages = 10
  config.max_wait_time = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    # We want to pause for super short time, shorter than processing
    pause(messages.last.offset + 1, 1)

    messages.each do |message|
      DT[:messages] << [message.raw_payload, Time.now.to_f]
    end

    sleep(1)
  end
end

draw_routes(Consumer)

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:messages].size >= 100
end

assert_equal elements, DT[:messages].map(&:first)

previous = nil
DT[:messages].map(&:last).each do |time|
  unless previous
    previous = time
    next
  end

  assert (time - previous) < 4_000

  previous = time
end
