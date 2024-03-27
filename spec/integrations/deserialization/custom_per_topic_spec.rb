# frozen_string_literal: true

# Karafka should allow to setup defaults and never use them as it uses per topic config

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[topic.name] = [message.payload, message.key, message.headers]
    end
  end
end

draw_routes do
  defaults do
    deserializers(
      payload: ->(_message) { 0 },
      key: ->(_headers) { 1 },
      headers: ->(_headers) { 2 }
    )
  end

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

produce(DT.topics[0], 'm1', headers: { 'test' => '1' }, key: 'x1')
produce(DT.topics[1], 'm2', headers: { 'test' => '2' }, key: 'x2')

start_karafka_and_wait_until do
  DT[DT.topics[0]].size >= 1 &&
    DT[DT.topics[1]].size >= 1
end

assert_equal DT[DT.topics[0]][0], 'm11'
assert_equal DT[DT.topics[0]][1], 'x11'
assert_equal DT[DT.topics[0]][2][:nested1], { 'test' => '1' }

assert_equal DT[DT.topics[1]][0], 'm22'
assert_equal DT[DT.topics[1]][1], 'x22'
assert_equal DT[DT.topics[1]][2][:nested2], { 'test' => '2' }
