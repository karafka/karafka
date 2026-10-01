# frozen_string_literal: true

# Share group (KIP-932) records are deserialized lazily: only payloads that are requested get
# deserialized, using the topic custom deserializer.

setup_karafka

class Deserializer
  def call(message)
    message.raw_payload.to_i
  end
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      # This will trigger deserialization only for even numbers
      DT[:payloads] << message.payload if (message.raw_payload.to_i % 2).zero?

      DT[:messages] << message
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
      deserializer Deserializer.new
    end
  end
end

setup_share_group

produce_many(DT.topic, Array.new(100, &:to_s))

start_karafka_and_wait_until do
  DT[:messages].size >= 100
end

assert_equal 100, DT[:messages].size
assert_equal 50, DT[:messages].count(&:deserialized?)
assert_equal (0..98).step(2).to_a, DT[:payloads].sort
