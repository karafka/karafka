# frozen_string_literal: true

# Share group (KIP-932) consumers do not get more records at once than defined with
# `max_messages`, like consumer groups, even when a single poll acquires more of them.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:counts] << messages.size

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      max_messages 5
      # Allow a single poll to acquire more records than one consume gets
      kafka(
        "bootstrap.servers": "127.0.0.1:9092",
        "max.poll.records": 100,
        "statistics.interval.ms": 100
      )
      consumer Consumer
    end
  end
end

setup_share_group

elements = DT.uuids(40)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 40
end

assert_equal elements.sort, DT[:accepted].uniq.sort
assert DT[:counts].max <= 5
assert DT[:counts].size >= 8
