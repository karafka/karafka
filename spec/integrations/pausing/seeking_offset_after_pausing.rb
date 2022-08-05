# frozen_string_literal: true

# After we pause and continue processing, we should be able to seek to previous offset and after
# un-pausing, we should be able to start from where we wanted (not from where we paused)

setup_karafka do |config|
  config.max_messages = 5
  config.pause_timeout = 5_000
  config.pause_max_timeout = 25_000
  config.pause_with_exponential_backoff = false
  config.manual_offset_management = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    @first_message ||= messages.first

    unless @paused
      @paused = true
      pause(messages.last.offset + 5)
      seek(@first_message.offset)
    end

    messages.each do |message|
      DT[:messages] << message.offset
    end
  end
end

draw_routes(Consumer)

20.times { |i| produce(DT.topic, i.to_s) }

start_karafka_and_wait_until do
  DT[:messages].size > 20
end

assert DT[:messages].size > 20
assert_equal 20, DT[:messages].uniq.size
