# frozen_string_literal: true

# Share group (KIP-932) release: a released record is returned to the group and redelivered.
# Here we release each record the first time we see it and accept it on redelivery.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:received] << message.raw_payload

      if DT[:received].count(message.raw_payload) == 1
        mark_as_released(message)
      else
        DT[:accepted] << message.raw_payload
        mark_as_accepted(message)
      end
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

elements = DT.uuids(5)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].sort == elements.sort
end

# Every record was delivered at least twice: once released, then redelivered and accepted
assert_equal elements.sort, DT[:accepted].sort
assert(elements.all? { |payload| DT[:received].count(payload) >= 2 })
