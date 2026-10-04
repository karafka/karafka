# frozen_string_literal: true

# Share group (KIP-932) with multiple topics: one share group subscribed to several topics
# receives and accepts every topic's records, attributed to the right topic.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[message.topic] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
    end

    topic DT.topics[1] do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topics[0])
setup_share_group(DT.topics[1])

first = DT.uuids(10)
second = DT.uuids(10)
produce_many(DT.topics[0], first)
produce_many(DT.topics[1], second)

start_karafka_and_wait_until do
  DT[DT.topics[0]].size >= 10 && DT[DT.topics[1]].size >= 10
end

assert_equal first.sort, DT[DT.topics[0]].sort
assert_equal second.sort, DT[DT.topics[1]].sort
