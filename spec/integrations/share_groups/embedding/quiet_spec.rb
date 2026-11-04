# frozen_string_literal: true

# Karafka should be able to run a share group (KIP-932) as embedded code and respond to quiet:
# consumption stops, the shutdown hook runs once per consumer when the process is finally stopped
# and records arriving while quiet are not consumed.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end

  def shutdown
    DT[:shutdown] << 1
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

elements = DT.uuids(50)
produce_many(DT.topic, elements)

Karafka::Embedded.start

sleep(0.1) until DT[:accepted].size >= 50

# We quiet it 10 times just to see if that crashes anything
10.times { Karafka::Embedded.quiet }

sleep(0.1) until Karafka::App.quiet?

# Records produced while quiet should not be picked up
produce_many(DT.topic, DT.uuids(10))

sleep(2)

10.times { Karafka::Embedded.stop }

assert_equal elements.sort, DT[:accepted].sort
assert_equal [1], DT[:shutdown]
