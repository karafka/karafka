# frozen_string_literal: true

# Share group (KIP-932) should be able to consume multiple topics with one worker.

setup_karafka do |config|
  config.concurrency = 1
end

class Consumer1 < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[Thread.current.object_id] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

class Consumer2 < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[Thread.current.object_id] << message.raw_payload
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

elements = DT.uuids(20)
produce_many(DT.topics[0], elements.first(10))
produce_many(DT.topics[1], elements.last(10))

start_karafka_and_wait_until do
  DT.data.values.flatten.size >= 20
end

assert_equal 1, DT.data.keys.uniq.size
assert_equal elements.sort, DT.data.values.flatten.sort
