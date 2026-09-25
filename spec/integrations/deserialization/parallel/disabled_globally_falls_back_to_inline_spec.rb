# frozen_string_literal: true

# When parallel deserialization is disabled globally but enabled on the topic,
# messages should still be deserialized inline (no Ractors used)

setup_karafka do |config|
  config.concurrency = 2
  config.deserializing.parallel.active = false
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
      parallel: true
    )
  end
end

payloads = Array.new(20) { |i| { "index" => i }.to_json }

produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[:payloads].size >= 20
end

assert_equal 20, DT[:payloads].size

indices = DT[:payloads].map { |p| p["index"] }.sort
assert_equal (0..19).to_a, indices
