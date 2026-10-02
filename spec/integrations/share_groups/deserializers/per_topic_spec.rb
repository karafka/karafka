# frozen_string_literal: true

# Share group (KIP-932) topics should use their own payload, key and headers deserializers over
# the routing defaults ones.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[topic.name] = [message.payload, message.key, message.headers]
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  defaults do
    deserializers(
      payload: ->(_message) { 0 },
      key: ->(_headers) { 1 },
      headers: ->(_headers) { 2 }
    )
  end

  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer

      deserializers(
        payload: ->(message) { "#{message.raw_payload}1" },
        key: ->(headers) { "#{headers.raw_key}1" },
        headers: ->(headers) { { nested1: headers.raw_headers } }
      )
    end

    topic DT.topics[1] do
      consumer Consumer

      deserializers(
        payload: ->(message) { "#{message.raw_payload}2" },
        key: ->(headers) { "#{headers.raw_key}2" },
        headers: ->(headers) { { nested2: headers.raw_headers } }
      )
    end
  end
end

setup_share_group(DT.topics[0])
setup_share_group(DT.topics[1])

produce(DT.topics[0], "m1", headers: { "test" => "1" }, key: "x1")
produce(DT.topics[1], "m2", headers: { "test" => "2" }, key: "x2")

start_karafka_and_wait_until do
  DT.key?(DT.topics[0]) && DT.key?(DT.topics[1])
end

assert_equal "m11", DT[DT.topics[0]][0]
assert_equal "x11", DT[DT.topics[0]][1]
assert_equal({ "test" => "1" }, DT[DT.topics[0]][2][:nested1])

assert_equal "m22", DT[DT.topics[1]][0]
assert_equal "x22", DT[DT.topics[1]][1]
assert_equal({ "test" => "2" }, DT[DT.topics[1]][2][:nested2])
