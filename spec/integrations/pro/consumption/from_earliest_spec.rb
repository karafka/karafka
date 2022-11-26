# frozen_string_literal: true

# Karafka should be able to easily consume all the messages from earliest (default) exactly
# the same way with pro as it does without

setup_karafka

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
