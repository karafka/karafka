# frozen_string_literal: true

# Custom headers should be correctly produced and consumed end-to-end,
# including string values, empty values, and unicode content.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:headers] << message.headers
      DT[:offsets] << message.offset
    end
  end
end

draw_routes(Consumer)

# Produce messages with various header types
Karafka.producer.produce_sync(
  topic: DT.topic,
  payload: "message1",
  headers: { "x-trace-id" => "abc-123", "x-source" => "test" }
)

Karafka.producer.produce_sync(
  topic: DT.topic,
  payload: "message2",
  headers: { "x-empty" => "" }
)

Karafka.producer.produce_sync(
  topic: DT.topic,
  payload: "message3",
  headers: { "x-unicode" => "\u00e9\u00e8\u00ea" }
)

start_karafka_and_wait_until do
  DT[:headers].size >= 3
end

# All three messages should be consumed
assert_equal 3, DT[:headers].size

# Verify first message headers
assert_equal "abc-123", DT[:headers][0]["x-trace-id"]
assert_equal "test", DT[:headers][0]["x-source"]

# Verify empty header value
assert_equal "", DT[:headers][1]["x-empty"]

# Verify unicode header value (Kafka returns headers as ASCII-8BIT)
assert_equal "\u00e9\u00e8\u00ea", DT[:headers][2]["x-unicode"].force_encoding("UTF-8")
