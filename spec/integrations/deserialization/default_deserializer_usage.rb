# frozen_string_literal: true

# Karafka should be able to deserialize JSON messages

setup_karafka

jsons = Array.new(100) { { SecureRandom.uuid => rand.to_s } }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.payload
    end
  end
end

draw_routes(Consumer)

jsons.each { |data| produce(DT.topic, data.to_json) }

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert_equal jsons, DT[0]
assert_equal 1, DT.data.size
