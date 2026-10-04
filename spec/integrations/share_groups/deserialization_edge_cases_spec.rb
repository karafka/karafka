# frozen_string_literal: true

# Share group (KIP-932) consumers should handle payload edge cases without crashing: empty and
# tombstone (nil) payloads, invalid encodings and binary data, mixed formats in one topic and large
# deeply nested JSON documents. All of them are delivered once, intact.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:payloads] << message.raw_payload
      DT[:deliveries] << message.delivery_count
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
      deserializers(payload: ->(_message) {})
    end
  end
end

setup_share_group

def nested(depth)
  return "leaf" if depth <= 0

  { "level_#{depth}" => nested(depth - 1), "array_#{depth}" => (1..3).to_a }
end

payloads = [
  "",
  " ",
  "Hello UTF-8 world! 🌍",
  "Café: àáâãäå",
  "\xFF\xFE\x00\x00Invalid UTF-8".b,
  "\x00\x01\x02\xFF\xFE".b,
  '{"type":"json"}',
  "42",
  "<xml>data</xml>",
  "multi\nline\ntext",
  JSON.generate(nested(50)),
  JSON.generate({ "large" => { "chunk" => "A" * 100_000, "deep" => nested(10) } })
]

produce_many(DT.topic, payloads)
# Tombstone
Karafka.producer.produce_sync(topic: DT.topic, payload: nil)

start_karafka_and_wait_until do
  DT[:payloads].size >= payloads.size + 1
end

assert_equal [1], DT[:deliveries].uniq
assert_equal payloads.size + 1, DT[:payloads].size

payloads.each_with_index do |payload, index|
  assert_equal payload.b, DT[:payloads][index].b
end

assert DT[:payloads].last.nil?
assert_equal nested(50), JSON.parse(DT[:payloads][10])
assert_equal 100_000, JSON.parse(DT[:payloads][11])["large"]["chunk"].size
