# frozen_string_literal: true

# Karafka should invoke the `#initialized` method and things like topic, partition and messages
# should not be nil

setup_karafka

class Consumer < Karafka::BaseConsumer
  def initialized
    DT[:topic] = topic
    DT[:partition] = partition
    DT[:messages] = messages
  end

  def consume
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:messages)
end

assert_equal DT[:topic].name, DT.topic
assert_equal DT[:partition], 0
assert DT[:messages].empty?
