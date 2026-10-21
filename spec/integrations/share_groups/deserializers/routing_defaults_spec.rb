# frozen_string_literal: true

# Share group (KIP-932) topics should use the payload, key and headers deserializers declared via
# the routing defaults.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:results] << [message.payload, message.key, message.headers]
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
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[:results].size >= 1
end

assert_equal [[0, 1, 2]], DT[:results]
