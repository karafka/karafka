# frozen_string_literal: true

# Share group (KIP-932) consumers should handle malformed JSON gracefully: the default lazy JSON
# deserializer raises only when the payload is accessed, so the consumer can reject broken records
# and accept the valid ones without any of them being redelivered.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << message.delivery_count

      begin
        DT[:valid] << message.payload
        mark_as_accepted(message)
      rescue JSON::ParserError
        DT[:malformed] << message.raw_payload
        mark_as_rejected(message)
      end
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

valid = ['{"valid":"json"}', "[1,2,3]"]

malformed = [
  '{"unclosed": "object"',
  '{"trailing", "comma",}',
  '{"unescaped": "quote"inside"}',
  "[1,2,3,]",
  '{"key": }',
  '{key: "value"}',
  "not json at all",
  "{",
  "}",
  '{"key": "value" "another": "value"}',
  '{"number": 123.456.789}'
]

produce_many(DT.topic, valid + malformed)

start_karafka_and_wait_until do
  DT[:deliveries].size >= valid.size + malformed.size
end

# Give the broker a chance to redeliver anything that was not settled
sleep(5)

assert_equal [{ "valid" => "json" }, [1, 2, 3]], DT[:valid]
assert_equal malformed, DT[:malformed]
assert_equal [1], DT[:deliveries].uniq
assert_equal valid.size + malformed.size, DT[:deliveries].size
