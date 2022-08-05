# frozen_string_literal: true

# We should be able pause on a message we've already seen from the batch and should always start
# from it after resuming. This will mean, we just process same message over and over again.

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:messages] << messages.first.raw_payload

    # Pause for 1 second
    pause(messages.first.offset, 1_000)
  end
end

draw_routes(Consumer)

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DT.topic, data) }

start_karafka_and_wait_until do
  DT[:messages].size >= 10
end

assert_equal 1, DT[:messages].uniq.size
assert_equal elements[0], DT[:messages][0]
