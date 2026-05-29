# frozen_string_literal: true

# Karafka should support the produce-from-consumer pattern (ping-pong) using the Eof polling
# strategy (enable.partition.eof = true). Verifies that real-time message chaining works
# correctly when the Eof strategy is active - each consumed message triggers a new produce
# and the next message arrives and is consumed in turn.

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      next if message.payload > 10

      producer.produce_sync(
        topic: DT.topic,
        payload: (message.payload + 1).to_json
      )

      DT[0] << message.payload
    end
  end
end

draw_routes(Consumer)

produce(DT.topic, 0.to_json)

start_karafka_and_wait_until do
  DT[0].size > 10
end

assert_equal (0..10).to_a, DT[0]
