# frozen_string_literal: true

# After we pause and continue processing, we should be able to seek to previous offset and after
# un-pausing, we should be able to start from where we wanted (not from where we paused)

setup_karafka do |config|
  config.max_messages = 5
  config.pause_timeout = 2_000
  config.pause_max_timeout = 10_000
  config.pause_with_exponential_backoff = true
  config.manual_offset_management = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    @first_message ||= messages.first

    unless @paused
      @paused = true
      # Skip one from the next batch
      pause(messages.last.offset + 5)
      sleep 1
      seek(@first_message.offset)
    end

    messages.each do |message|
      DataCollector.data[:messages] << message.offset
    end
  end
end

draw_routes(Consumer)

20.times { |i| produce(DataCollector.topic, i.to_s) }

start_karafka_and_wait_until do
  DataCollector.data[:messages].size >= 25
end

assert_equal 25, DataCollector.data[:messages].size
assert_equal 20, DataCollector.data[:messages].uniq.size
