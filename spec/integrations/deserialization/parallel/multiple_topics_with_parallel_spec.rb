# frozen_string_literal: true

# Parallel deserialization should work correctly when multiple topics are consumed
# simultaneously, each with its own deserializer

setup_karafka do |config|
  config.concurrency = 4
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 2
  config.deserializing.parallel.min_payloads = 5
end

class JsonDeserializer
  def call(message)
    JSON.parse(message.raw_payload)
  end
end

class CsvDeserializer
  def call(message)
    message.raw_payload.split(",")
  end
end

class JsonConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:json] << message.payload
    end
  end
end

class CsvConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:csv] << message.payload
    end
  end
end

json_topic = DT.topics[0]
csv_topic = DT.topics[1]

draw_routes do
  topic json_topic do
    consumer JsonConsumer
    deserializing(
      payload: JsonDeserializer.new,
      parallel: true
    )
  end

  topic csv_topic do
    consumer CsvConsumer
    deserializing(
      payload: CsvDeserializer.new,
      parallel: true
    )
  end
end

json_payloads = Array.new(30) { |i| { "index" => i }.to_json }
csv_payloads = Array.new(30) { |i| "#{i},data_#{i},value" }

produce_many(json_topic, json_payloads)
produce_many(csv_topic, csv_payloads)

start_karafka_and_wait_until do
  DT[:json].size >= 30 && DT[:csv].size >= 30
end

assert_equal 30, DT[:json].size
assert_equal 30, DT[:csv].size

# Verify JSON topic messages
json_indices = DT[:json].map { |p| p["index"] }.sort
assert_equal (0..29).to_a, json_indices

# Verify CSV topic messages
DT[:csv].each do |payload|
  assert payload.is_a?(Array), "CSV payload should be an Array, got #{payload.class}"
  assert_equal 3, payload.size
end
