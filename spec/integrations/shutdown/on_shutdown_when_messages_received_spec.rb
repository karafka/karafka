# frozen_string_literal: true

# When we received messages, shutdown should kick in for every consumer that did any work

setup_karafka

topic1 = DT.topics[0]
topic2 = DT.topics[1]
topic3 = DT.topics[2]

class Consumer < Karafka::BaseConsumer
  def initialize
    super
    @id = SecureRandom.hex(6)
  end

  def consume
    DT[0] << 1
  end

  def shutdown
    DT[topic.name] << @id
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic topic1 do
      consumer Consumer
    end

    topic topic2 do
      consumer Consumer
    end

    # This one will do nothing
    topic topic3 do
      consumer Consumer
    end
  end
end

produce(topic1, '1')
produce(topic2, '1')

start_karafka_and_wait_until do
  DT[0].size >= 2
end

assert_equal 1, DT[topic1].size
assert_equal 1, DT[topic2].size
assert_equal 0, DT[topic3].size
assert_not_equal DT[topic1].first, DT[topic2].first
