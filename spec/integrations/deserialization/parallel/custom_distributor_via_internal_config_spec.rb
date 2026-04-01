# frozen_string_literal: true

# The internal distributor config should be swappable and used for payload distribution
# A custom distributor that always creates single-element batches should still produce
# correct results

# Custom distributor that creates one batch per message (maximum parallelism)
class SingleMessageDistributor
  def call(payloads, pool_size, min_payloads: 50)
    # One message per batch, capped at pool_size * 2
    max_batches = [pool_size * 2, payloads.size].min
    slice_size = (payloads.size + max_batches - 1) / max_batches
    payloads.each_slice(slice_size).to_a
  end
end

setup_karafka do |config|
  config.concurrency = 2
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 2
  config.deserializing.parallel.min_payloads = 5
  config.internal.deserializing.distributor = SingleMessageDistributor.new
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

payloads = Array.new(50) { |i| { "index" => i }.to_json }

produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[:payloads].size >= 50
end

assert_equal 50, DT[:payloads].size

indices = DT[:payloads].map { |p| p["index"] }.sort
assert_equal (0..49).to_a, indices

# Verify the custom distributor was used (it"s set in internal config)
assert(
  Karafka::App.config.internal.deserializing.distributor.is_a?(SingleMessageDistributor),
  "Internal distributor should be the custom one"
)
