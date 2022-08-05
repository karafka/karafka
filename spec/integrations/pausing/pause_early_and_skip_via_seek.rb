# frozen_string_literal: true

# We should be able to pause the partition and then seek to another offset
# After partition is un-paused, it should skip the messages we want to jump over

setup_karafka do |config|
  config.max_messages = 5
  config.pause_timeout = 2_000
  config.pause_max_timeout = 2_000
  config.pause_with_exponential_backoff = false
  config.manual_offset_management = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless @paused
      @paused = true
      # Pause on our first message
      pause(messages.first.offset)
      # And then skip via seek
      seek(messages.last.offset + 2)
      DT[:skipped] = messages.last.offset + 1
    end

    messages.each do |message|
      DT[:messages] << message.offset
    end
  end
end

draw_routes(Consumer)

20.times { |i| produce(DT.topic, i.to_s) }

start_karafka_and_wait_until do
  DT[:messages].size >= 19
end

assert_equal 19, DT[:messages].size
# This message should have been skipped when pausing and seeking
assert_equal false, DT[:messages].include?(DT[:skipped])
