# frozen_string_literal: true

# Karafka should be able to consume multiple topics with one worker

setup_karafka do |config|
  config.concurrency = 1
end

topic1 = DT.topics[0]
topic2 = DT.topics[1]

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do
      DT[Thread.current.object_id] << true
    end
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do
      DT[Thread.current.object_id] << true
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic topic1 do
      consumer Consumer1
    end

    topic topic2 do
      consumer Consumer2
    end
  end
end

produce_many(topic1, DT.uuids(10))
produce_many(topic2, DT.uuids(10))

start_karafka_and_wait_until do
  DT.data.values.flatten.size >= 20
end

assert_equal 1, DT.data.keys.uniq.size
assert_equal 20, DT.data.values.flatten.size
