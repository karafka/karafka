# frozen_string_literal: true

# Offset should move forward with metadata and should be deserialized with a custom deserializer.
# Because we disabled the cache completely, we should get linear auto-refreshed data

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed!(message, { offset: message.offset }.to_json)
      DT[:metadata] << offset_metadata.fetch('offset')
    end
  end
end

class JsonDeserializer
  def call(raw_metadata)
    JSON.parse(raw_metadata)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    offset_metadata(
      cache: false,
      deserializer: JsonDeserializer.new
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:metadata].size >= 100
end

assert_equal DT[:metadata], (0..99).to_a
