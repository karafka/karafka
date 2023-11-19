# frozen_string_literal: true

# Karafka should be able to consume and web tracking should not interfere

setup_karafka
setup_web

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert_equal elements, DT[0]
assert_equal 1, DT.data.size
