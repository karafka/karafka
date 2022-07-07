# frozen_string_literal: true

# When we received messages, shutdown should kick in for every consumer that did any work

setup_karafka

topic1 = DataCollector.topics[0]
topic2 = DataCollector.topics[1]
topic3 = DataCollector.topics[2]

class Consumer < Karafka::BaseConsumer
  def initialize
    super
    @id = SecureRandom.uuid
  end

  def consume
    DataCollector[0] << 1
  end

  def shutdown
    DataCollector[topic.name] << @id
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
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
  DataCollector[0].size >= 2
end

assert_equal 1, DataCollector[topic1].size
assert_equal 1, DataCollector[topic2].size
assert_equal 0, DataCollector[topic3].size
assert_not_equal DataCollector[topic1].first, DataCollector[topic2].first
