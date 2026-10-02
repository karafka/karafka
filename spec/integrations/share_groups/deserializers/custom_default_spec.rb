# frozen_string_literal: true

# Share group (KIP-932) topics should use a custom payload deserializer declared via the routing
# defaults (legacy single `deserializer` API).

class CustomDeserializer
  def call(message)
    message.raw_payload[0..6]
  end
end

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:payloads] << message.payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  defaults do
    deserializer CustomDeserializer.new
  end

  share_group DT.group do
    topic DT.topic do
      consumer Consumer
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
