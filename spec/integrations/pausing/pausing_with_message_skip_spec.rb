# frozen_string_literal: true

# We should be able to pause the partition in a way that would allow us to skip a message. This
# is not something you want to do in production, nonetheless use-case like this should be
# supported.

setup_karafka do |config|
  config.max_messages = 5
  config.pause_timeout = 2_000
  config.pause_max_timeout = 10_000
  config.pause_with_exponential_backoff = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless @paused
      @paused = true
      # Skip one from the next batch
      pause(messages.last.offset + 2)
      DT[:skipped] = messages.last.offset + 1
    end

    messages.each do |message|
      DT[:messages] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:messages].size >= 19
end

assert_equal 19, DT[:messages].size
# This message should have been skipped when pausing
assert_equal false, DT[:messages].include?(DT[:skipped])
