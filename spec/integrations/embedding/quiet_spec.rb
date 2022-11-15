# frozen_string_literal: true

# Karafka should be able to run as embedded code and should respond to quiet.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end

  def shutdown
    DT[:shutdown] << 1
  end

  def revoked
    DT[:revoked] << 1
  end
end

draw_routes(Consumer)

elements = DT.uuids(100)
produce_many(DT.topic, elements)

# Run Karafka
Karafka::Embedded.start

sleep(0.1) until DT[0].size >= 100

# We quiet and stop it 10 times just to see if that crashes anything ;)
10.times { Karafka::Embedded.quiet }

sleep(5)

10.times { Karafka::Embedded.stop }

assert_equal elements, DT[0]
assert_equal 2, DT.data.size
assert_equal [1], DT[:shutdown]
assert_equal [], DT[:revoked]
