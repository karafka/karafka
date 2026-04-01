# frozen_string_literal: true

# When messages arrive in multiple polls, each batch should be dispatched and deserialized
# independently via the Ractor pool without interference between batches

setup_karafka do |config|
  config.concurrency = 2
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 2
  config.deserializing.parallel.min_payloads = 5
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:batches] << messages.size
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

# Produce in two separate calls to encourage multiple polls
first_batch = Array.new(20) { |i| { 'index' => i, 'batch' => 1 }.to_json }
produce_many(DT.topic, first_batch)

# Small delay to help separate into different polls
sleep(1)

second_batch = Array.new(20) { |i| { 'index' => i + 20, 'batch' => 2 }.to_json }
produce_many(DT.topic, second_batch)

start_karafka_and_wait_until do
  DT[:payloads].size >= 40
end

assert_equal 40, DT[:payloads].size

indices = DT[:payloads].map { |p| p['index'] }.sort
assert_equal (0..39).to_a, indices

# Should have received multiple batches (at least 2 consume calls)
assert DT[:batches].size >= 2, "Expected multiple batches, got #{DT[:batches].size}"
