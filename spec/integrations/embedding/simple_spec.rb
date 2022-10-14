# frozen_string_literal: true

# Karafka should be able to run as embedded code.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(100)
produce_many(DT.topic, elements)

# Run Karafka
Karafka::Embedded.start

sleep(0.1) until DT[0].size >= 100

# We stop it 10 times just to see if that crashes anything ;)
10.times { Karafka::Embedded.stop }

assert_equal elements, DT[0]
assert_equal 1, DT.data.size
