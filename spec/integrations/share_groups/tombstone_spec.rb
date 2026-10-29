# frozen_string_literal: true

# Share group (KIP-932) consumes tombstone records with the default deserializer without issues.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:records] << [message.key, message.payload, message.tombstone?]
      mark_as_accepted(message)
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

produce(DT.topic, nil, key: "a")

start_karafka_and_wait_until do
  DT.key?(:records)
end

assert_equal [["a", nil, true]], DT[:records]
