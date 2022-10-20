# frozen_string_literal: true

# Karafka should be able to easily consume messages sent from one topic to another

setup_karafka do |config|
  config.max_wait_time = 100
end

create_topic(name: DT.topics[0])
create_topic(name: DT.topics[1])

produce(DT.topic, 0.to_json)

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      producer.produce_async(
        topic: DT.topics[1],
        payload: (message.payload + 1).to_json
      )

      DT[0] << message.payload
    end
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      producer.produce_async(
        topic: DT.topics[0],
        payload: (message.payload + 1).to_json
      )

      DT[0] << message.payload
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer1
  end

  topic DT.topics[1] do
    consumer Consumer2
  end
end

start_karafka_and_wait_until do
  DT[0].size > 50
end

assert_equal (0..60).to_a[0..(DT[0].size - 1)], DT[0]
