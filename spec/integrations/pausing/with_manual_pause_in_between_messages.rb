# frozen_string_literal: true

# We should be able to manually pause for any time we want, bypassing the default pause time
# if we declare the pause time ourselves.

setup_karafka do |config|
  config.max_messages = 1
  # We assign a really big value as we want to make sure this value is not used with this spec
  # since we override this
  config.pause_timeout = 1_000_000
  config.pause_max_timeout = 1_000_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[:times] << Time.now.to_f
      DataCollector.data[:messages] << message.raw_payload
    end

    # Pause for 1 second
    pause(messages.last.offset + 1, 1_000)
  end
end

draw_routes(Consumer)

elements = Array.new(10) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data[:messages].size >= 10
end

# Pausing and getting back to consumption should not mess order or number of messages
assert_equal elements, DataCollector.data[:messages]

previous = nil

# Pausing should also be at least as much as we paused + time to get back after un-pause
DataCollector.data[:times].each do |timestamp|
  unless previous
    previous = timestamp
    next
  end

  pause = (timestamp - previous)
  assert_equal true, pause >= 1 && pause <= 5

  previous = timestamp
end
