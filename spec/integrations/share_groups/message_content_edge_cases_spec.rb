# frozen_string_literal: true

# Share group (KIP-932) handles edge case record contents (blank, null bytes, invalid UTF-8,
# binary, long keys) and delivers them unchanged.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << [message.key, message.raw_payload]
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

test_messages = [
  { payload: " " },
  { payload: "Hello\x00World\x00Test" },
  { payload: "payload_with_long_key", key: "k" * 500 },
  { payload: "Valid text\xFF\xFE\x80Invalid UTF-8" },
  { payload: "\x00\x01\x02\xFF\xFE\xFD" * 50 },
  { payload: "zażółć gęślą jaźń 🚀" }
]

test_messages.each do |test_msg|
  produce(DT.topic, test_msg[:payload], key: test_msg[:key])
end

start_karafka_and_wait_until do
  DT[:consumed].size >= test_messages.size
end

expected = test_messages.map { |test_msg| [test_msg[:key], test_msg[:payload].b] }
consumed = DT[:consumed].map { |key, payload| [key, payload.b] }

assert_equal expected.sort_by(&:last), consumed.sort_by(&:last)
