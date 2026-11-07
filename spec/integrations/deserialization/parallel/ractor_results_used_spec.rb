# frozen_string_literal: true

# Karafka should use the results produced by Ractor workers instead of deserializing inline
# on the worker thread. The deserializer tags its output with the Ractor it ran in.

setup_karafka do |config|
  config.concurrency = 1
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 2
  config.deserializing.parallel.min_payloads = 1
end

class RactorTaggingDeserializer
  def call(message)
    source = (Ractor.current == Ractor.main) ? "main" : "ractor"
    { "source" => source, "bytes" => message.raw_payload.bytesize }
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:sources] << message.payload["source"]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializing(
      payload: RactorTaggingDeserializer.new.freeze,
      parallel: true
    )
  end
end

produce_many(DT.topic, Array.new(100) { |i| i.to_s })

start_karafka_and_wait_until do
  DT[:sources].size >= 100
end

assert_equal 100, DT[:sources].size
assert DT[:sources].all?("ractor"), DT[:sources].tally.inspect
