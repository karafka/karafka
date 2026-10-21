# frozen_string_literal: true

# Karafka should be able to run a share group (KIP-932) as embedded code: records are consumed and
# accepted from a background thread and repeated stops do not crash anything.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:execution_mode] = Karafka::Server.execution_mode.to_sym

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
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

# We stop it 10 times just to see if that crashes anything
10.times { Karafka::Embedded.stop }

assert Karafka::App.terminated?
assert_equal elements.sort, DT[:accepted].sort
assert_equal :embedded, DT[:execution_mode]
