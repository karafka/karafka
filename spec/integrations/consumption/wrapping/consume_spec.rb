# frozen_string_literal: true

# Karafka should allow for wrapping on consume

setup_karafka

PRODUCER = rand

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:producer] = producer

    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end

  def wrap(action)
    DT[:actions] << action

    return yield unless action == :consume

    self.producer = PRODUCER

    yield

    self.producer = nil
  end
end

draw_routes(Consumer)

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal PRODUCER, DT[:producer]
assert_equal DT[:actions].uniq, %i[consume shutdown]
