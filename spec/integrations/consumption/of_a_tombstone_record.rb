# frozen_string_literal: true

# Karafka should not have any problems of consuming of a tombstone record with the default
# deserializer

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.payload
    end
  end
end

draw_routes(Consumer)

produce(DT.topic, nil, key: 'a')

start_karafka_and_wait_until do
  DT[0].size >= 1
end

assert_equal 1, DT.data.size
assert_equal nil, DT[0].first
