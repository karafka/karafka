# frozen_string_literal: true

# A deserializer that cannot be copied into a Ractor (a lambda) should not crash the process.
# Such batches should fall back to inline deserialization.

setup_karafka do |config|
  config.concurrency = 1
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 2
  config.deserializing.parallel.min_payloads = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:payloads] << message.payload
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializing(
      payload: ->(message) { message.raw_payload.to_i },
      parallel: true
    )
  end
end

produce_many(DT.topic, Array.new(100) { |i| i.to_s })

start_karafka_and_wait_until do
  DT[:payloads].size >= 100
end

assert_equal (0...100).to_a, DT[:payloads]
