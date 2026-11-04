# frozen_string_literal: true

# Share group (KIP-932) consumers can produce from within `#consume`, both via the `producer` and
# the delegated aliases. Here they ping-pong records back into the same topic.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:payloads] << message.payload
      mark_as_accepted(message)

      next if message.payload >= 10

      case message.payload % 5
      when 0
        producer.produce_sync(topic: topic.name, payload: (message.payload + 1).to_json)
      when 1
        produce_sync(topic: topic.name, payload: (message.payload + 1).to_json)
      when 2
        produce_async(topic: topic.name, payload: (message.payload + 1).to_json)
      when 3
        produce_many_sync([{ topic: topic.name, payload: (message.payload + 1).to_json }])
      else
        produce_many_async([{ topic: topic.name, payload: (message.payload + 1).to_json }])
      end
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce(DT.topic, 0.to_json)

start_karafka_and_wait_until do
  DT[:payloads].uniq.size >= 11
end

assert_equal (0..10).to_a, DT[:payloads].uniq.sort
