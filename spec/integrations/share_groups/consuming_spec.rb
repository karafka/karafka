# frozen_string_literal: true

# Share group (KIP-932) basics: consume records and accept them. Accepted records are not
# redelivered, so we get exactly the produced set.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
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

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].size >= 20
end

assert_equal elements.sort, DT[:accepted].sort
