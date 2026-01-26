# frozen_string_literal: true

# Karafka should not have any problems of consuming of a tombstone record with the default
# deserializer

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.payload
      DT[:has_tombstone] = true if message.tombstone?
    end
  end
end

draw_routes(Consumer)

produce(DT.topic, nil, key: "a")

start_karafka_and_wait_until do
  DT.key?(0)
end

assert_equal 2, DT.data.size
assert_equal nil, DT[0].first
assert DT[:has_tombstone]
