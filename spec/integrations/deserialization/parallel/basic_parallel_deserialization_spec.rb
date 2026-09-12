# frozen_string_literal: true

# Karafka should be able to deserialize messages in parallel using Ractors
# when parallel deserialization is enabled globally and on the topic

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
      parallel: true
    )
  end
end

payloads = Array.new(100) { |i| { "index" => i, "data" => "value_#{i}" }.to_json }

produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[:payloads].size >= 100
end

assert_equal 100, DT[:payloads].size

# Verify all messages were deserialized correctly
indices = DT[:payloads].map { |p| p["index"] }.sort
assert_equal (0..99).to_a, indices

# Verify payload content
DT[:payloads].each do |payload|
  assert payload.is_a?(Hash), "Payload should be a Hash, got #{payload.class}"
  assert payload.key?("index"), "Payload should have index key"
  assert payload.key?("data"), "Payload should have data key"
end
