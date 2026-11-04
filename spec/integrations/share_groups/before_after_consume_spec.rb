# frozen_string_literal: true

# Share group (KIP-932) consumers run the `#on_before_consume` and `#on_after_consume` hooks around
# `#consume` with the same batch available. Those are not part of the official API, but we make
# sure they run as expected.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def on_before_consume
    messages.each { |message| DT[:prep] << message.raw_payload }

    super
  end

  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
      mark_as_accepted(message)
    end
  end

  def on_after_consume
    messages.each { |message| DT[:post] << message.raw_payload }

    super
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

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:post].size >= 100
end

assert_equal elements.sort, DT[:consumed].sort
assert_equal DT[:prep], DT[:consumed]
assert_equal DT[:post], DT[:consumed]
