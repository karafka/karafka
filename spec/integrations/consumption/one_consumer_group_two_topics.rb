# frozen_string_literal: true

# Karafka should be able to consume two topics with same consumer group

setup_karafka

topic1 = DT.topics[0]
topic2 = DT.topics[1]
topic1_data = Array.new(10) { { SecureRandom.uuid => rand.to_s } }
topic2_data = Array.new(10) { { SecureRandom.uuid => rand.to_s } }

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[topic.name] << message.payload
    end
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[topic.name] << message.payload
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

topic1_data.each { |data| produce(topic1, data.to_json) }
topic2_data.each { |data| produce(topic2, data.to_json) }

start_karafka_and_wait_until do
  DT.data.values.flatten.size >= 20
end

assert_equal topic1_data, DT[topic1]
assert_equal topic2_data, DT[topic2]
assert_equal 2, DT.data.size
