# frozen_string_literal: true

# With usage of `#pause` we should be able to ensure we always process messages with certain delay
# not to process messages that are "fresh"

MINIMUM_AGE = 10 # 10 seconds

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      message_age = Time.now.to_i - message.timestamp.to_i

      if message_age < MINIMUM_AGE
        # Pause requires milliseconds
        pause(message.offset, (MINIMUM_AGE - message_age) * 1_000)
        return
      end

      DT[:ages] << message_age
      DT[:offsets] << message.offset
    end
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(2))
  sleep(1)

  DT[:ages].size >= 20
end

# All the messages when consumed need to be at least 10 seconds old
# The deviation comes from polling times
assert DT[:ages].min >= MINIMUM_AGE

# All messages should be consumed and in order
previous = nil

DT[:offsets].each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
