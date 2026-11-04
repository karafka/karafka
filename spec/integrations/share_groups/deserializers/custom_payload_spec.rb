# frozen_string_literal: true

# Share group (KIP-932) records should be deserialized with a custom payload deserializer declared
# on the share topic.

setup_karafka

class CustomDeserializer
  def call(message)
    message.raw_payload[0..6]
  end
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:payloads] << message.payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
      deserializers(payload: CustomDeserializer.new)
    end
  end
end

setup_share_group

produce_many(DT.topic, Array.new(100) { |i| "message#{i}" })

start_karafka_and_wait_until do
  DT[:payloads].size >= 100
end

assert_equal %w[message], DT[:payloads].uniq
assert_equal 100, DT[:payloads].size
