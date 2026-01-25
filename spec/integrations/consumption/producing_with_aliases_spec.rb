# frozen_string_literal: true

# Karafka should be able to produce from consumers using the delegated aliased API

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] = true

    produce_async(topic: topic.name, payload: "1")
    produce_sync(topic: topic.name, payload: "2")
    produce_many_async([{ topic: topic.name, payload: "2" }])
    produce_many_sync([{ topic: topic.name, payload: "2" }])
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

# No checks needed. If aliases wouldn't work, will crash
