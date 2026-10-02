# frozen_string_literal: true

# When parallel deserialization is enabled globally but a specific topic has parallel: false,
# that topic should use inline deserialization (no Ractors)

setup_karafka do |config|
  config.concurrency = 2
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 2
  config.deserializing.parallel.min_payloads = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:payloads] << message.payload
    end
  end
end

class JsonDeserializer
  def call(message)
    JSON.parse(message.raw_payload)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializing(
      payload: JsonDeserializer.new,
      parallel: false
    )
  end
end

payloads = Array.new(50) { |i| { "index" => i }.to_json }

produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[:payloads].size >= 50
end

assert_equal 50, DT[:payloads].size

indices = DT[:payloads].map { |p| p["index"] }.sort
assert_equal (0..49).to_a, indices
