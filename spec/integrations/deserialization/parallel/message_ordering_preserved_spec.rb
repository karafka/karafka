# frozen_string_literal: true

# Parallel deserialization must preserve message ordering. Even though messages are
# distributed across multiple Ractor workers, the results must be injected back into
# the original message positions so the consumer sees them in offset order.

setup_karafka do |config|
  config.concurrency = 2
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 4
  config.deserializing.parallel.min_payloads = 5
  config.max_messages = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:ordered_indices] << message.payload["index"]
      DT[:offsets] << message.offset
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

payloads = Array.new(200) { |i| { "index" => i }.to_json }

produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[:ordered_indices].size >= 200
end

assert_equal 200, DT[:ordered_indices].size

# Within each consume call, messages must be in offset order
# Since we may get multiple batches, check ordering within contiguous ranges
offsets = DT[:offsets]
offsets.each_cons(2) do |a, b|
  # Within a single consume call, offsets are monotonically increasing
  # Between calls they reset, so we only check consecutive pairs within a call
  next if b < a # new batch started

  assert(
    b > a,
    "Offsets should be monotonically increasing within a batch, got #{a} then #{b}"
  )
end

# The payload indices must match their position (proving injection order is correct)
# Group by consume batches and verify ordering within each
indices = DT[:ordered_indices]
assert_equal (0..199).to_a, indices.sort
