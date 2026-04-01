# frozen_string_literal: true

# A large batch should be distributed across Ractor workers and all messages
# should arrive correctly deserialized with proper ordering preserved

setup_karafka do |config|
  config.concurrency = 2
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 4
  config.deserializing.parallel.min_payloads = 50
  config.max_messages = 10_000
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

payloads = Array.new(500) { |i| { 'index' => i, 'data' => 'x' * 100 }.to_json }

produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[:payloads].size >= 500
end

assert_equal 500, DT[:payloads].size

indices = DT[:payloads].map { |p| p['index'] }.sort
assert_equal (0..499).to_a, indices
