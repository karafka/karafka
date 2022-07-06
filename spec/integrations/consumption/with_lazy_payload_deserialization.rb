# frozen_string_literal: true

# Karafka when processing messages should deserialize only in case where we request payload to be
# deserialized even when iterating over all the objects.

setup_karafka

class Deserializer
  def call(message)
    message.raw_payload.to_i
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # This will trigger deserialization only for even numbers
      message.payload if (message.raw_payload.to_i % 2).zero?

      DataCollector[0] << message
    end
  end
end

draw_routes do
  topic DataCollector.topic do
    consumer Consumer
    deserializer Deserializer.new
  end
end

100.times { |counter| produce(DataCollector.topic, counter.to_s) }

start_karafka_and_wait_until do
  DataCollector[0].size >= 100
end

assert_equal 100, DataCollector[0].size
assert_equal 50, DataCollector[0].count(&:deserialized?)
