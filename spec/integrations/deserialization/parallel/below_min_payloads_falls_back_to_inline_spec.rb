# frozen_string_literal: true

# When the batch size is below min_payloads threshold, parallel deserialization should
# fall back to inline (Immediate) deserialization transparently

setup_karafka do |config|
  config.concurrency = 2
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 2
  config.deserializing.parallel.min_payloads = 200
  config.max_messages = 10
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

# Produce fewer messages than min_payloads so inline path is used
payloads = Array.new(10) { |i| { 'index' => i }.to_json }

produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[:payloads].size >= 10
end

assert_equal 10, DT[:payloads].size

indices = DT[:payloads].map { |p| p['index'] }.sort
assert_equal (0..9).to_a, indices
