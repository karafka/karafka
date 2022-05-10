# frozen_string_literal: true

# We should be able to do things like pausing and resume in the same consumer flow.
# This should not break the ordering

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    # We pause for a really long time, so unless our resume works, this will hang
    pause(messages.last.offset + 1, 100_000)

    messages.each do |message|
      DataCollector.data[:messages] << message.raw_payload
    end

    resume
  end
end

draw_routes(Consumer)

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data[:messages].size >= 100
end

assert_equal elements, DataCollector.data[:messages]
