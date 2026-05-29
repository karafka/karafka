# frozen_string_literal: true

# Karafka should be able to consume all data from the beginning using the Eof polling strategy
# (enable.partition.eof = true). Verifies that basic delivery correctness is preserved when
# the Eof strategy is active.

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

Thread.new do
  sleep(0.1) while DT[0].size < 100
  Karafka::Server.stop
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

Karafka::Server.run

assert_equal elements, DT[0]
assert_equal 1, DT.data.size
