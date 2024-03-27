# frozen_string_literal: true

# Karafka should be able to use routing default deserializers

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [message.payload, message.key, message.headers]
    end
  end
end

draw_routes do
  defaults do
    deserializers(
      payload: ->(_payload) { 0 },
      key: ->(_payload) { 1 },
      headers: ->(_payload) { 2 }
    )
  end

  topic DT.topic do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[0].size >= 1
end

assert_equal DT[0][0][0], 0
assert_equal DT[0][0][1], 1
assert_equal DT[0][0][2], 2
