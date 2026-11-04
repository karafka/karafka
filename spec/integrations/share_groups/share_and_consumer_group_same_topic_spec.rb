# frozen_string_literal: true

# Share group (KIP-932) and a regular consumer group consuming the same topic in one process are
# independent: each of them gets every record.

setup_karafka

class ShareConsumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:share] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumer] << message.raw_payload
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.groups[0] do
    topic DT.topic do
      consumer ShareConsumer
    end
  end

  consumer_group DT.groups[1] do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group(DT.topic, DT.groups[0])

elements = DT.uuids(50)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:share].size >= 50 && DT[:consumer].size >= 50
end

assert_equal elements.sort, DT[:share].sort
assert_equal elements, DT[:consumer]
