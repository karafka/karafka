# frozen_string_literal: true

# Karafka should be able to easily consume and produce messages from consumer

setup_karafka

produce(DT.topic, 0.to_json)

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

start_karafka_and_wait_until do
  DT[0].size > 10
end

assert_equal (0..10).to_a, DT[0]
