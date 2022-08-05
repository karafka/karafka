# frozen_string_literal: true

# Karafka should be able to consume all the data from beginning

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

Thread.new do
  sleep(0.1) while DT[0].size < 100
  Karafka::Server.stop
end

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DT.topic, data) }

Karafka::Server.run

assert_equal elements, DT[0]
assert_equal 1, DT.data.size
