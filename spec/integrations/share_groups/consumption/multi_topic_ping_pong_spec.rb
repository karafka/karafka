# frozen_string_literal: true

# Share group (KIP-932) consumers should be able to easily consume records sent from one topic of
# the share group to another and back.

setup_karafka do |config|
  config.max_wait_time = 100
end

class Consumer1 < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      producer.produce_async(topic: DT.topics[1], payload: (message.payload + 1).to_json)

      DT[0] << message.payload
      mark_as_accepted(message)
    end
  end
end

class Consumer2 < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      producer.produce_async(topic: DT.topics[0], payload: (message.payload + 1).to_json)

      DT[0] << message.payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer1
    end

    topic DT.topics[1] do
      consumer Consumer2
    end
  end
end

setup_share_group(DT.topics[0])
setup_share_group(DT.topics[1])

produce(DT.topics[0], 0.to_json)

start_karafka_and_wait_until do
  DT[0].size > 50
end

assert_equal (0..(DT[0].size - 1)).to_a, DT[0]
