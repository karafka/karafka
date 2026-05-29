# frozen_string_literal: true

# Karafka should correctly consume two topics within the same consumer group using the Eof
# polling strategy (enable.partition.eof = true). Verifies that multi-topic interleaving
# through the buffer works correctly when both partitions can independently signal EOF.

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
end

topic1 = DT.topics[0]
topic2 = DT.topics[1]
topic1_data = Array.new(10) { { SecureRandom.hex(6) => rand.to_s } }
topic2_data = Array.new(10) { { SecureRandom.hex(6) => rand.to_s } }

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
  topic topic1 do
    consumer Consumer1
  end

  topic topic2 do
    consumer Consumer2
  end
end

produce_many(topic1, topic1_data.map(&:to_json))
produce_many(topic2, topic2_data.map(&:to_json))

start_karafka_and_wait_until do
  DT.data.values.flatten.size >= 20
end

assert_equal topic1_data, DT[topic1]
assert_equal topic2_data, DT[topic2]
assert_equal 2, DT.data.size
