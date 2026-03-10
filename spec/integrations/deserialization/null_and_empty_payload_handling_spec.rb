# frozen_string_literal: true

# Messages with nil payload (tombstones) and empty string payloads should be handled
# gracefully by Karafka consumers without crashing.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:payloads] << message.raw_payload
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializers(
      payload: ->(_message) {}
    )
  end
end

# Produce messages with various payload types
produce(DT.topic, "")
produce(DT.topic, " ")
produce(DT.topic, "normal payload")

# Produce a tombstone (nil payload)
Karafka.producer.produce_sync(
  topic: DT.topic,
  payload: nil
)

start_karafka_and_wait_until do
  DT[:payloads].size >= 4
end

# All messages should be consumed without crashing
assert_equal 4, DT[:payloads].size
# Verify the raw payloads are accessible
assert_equal "", DT[:payloads][0]
assert_equal " ", DT[:payloads][1]
assert_equal "normal payload", DT[:payloads][2]
assert DT[:payloads][3].nil?
