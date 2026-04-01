# frozen_string_literal: true

# When a single message fails deserialization in a Ractor worker, only that message should
# be affected. Other messages in the batch should deserialize normally. The failed message
# should fall back to lazy deserialization on access.

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
    rescue JSON::ParserError
      DT[:errors] << message.raw_payload
    end
  end
end

class StrictJsonDeserializer
  def call(message)
    JSON.parse(message.raw_payload)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializing(
      payload: StrictJsonDeserializer.new,
      parallel: true
    )
  end
end

# Mix valid and invalid JSON messages
payloads = []
20.times { |i| payloads << { 'index' => i }.to_json }
payloads << 'not valid json'
payloads << '{"broken":'
20.times { |i| payloads << { 'index' => i + 20 }.to_json }

produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[:payloads].size + DT[:errors].size >= payloads.size
end

# All valid messages should have been deserialized
assert_equal 40, DT[:payloads].size

# The 2 malformed messages should have triggered deserialization errors
assert_equal 2, DT[:errors].size
assert DT[:errors].include?('not valid json')
assert DT[:errors].include?('{"broken":')
