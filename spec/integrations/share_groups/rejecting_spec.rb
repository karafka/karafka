# frozen_string_literal: true

# Share group (KIP-932) reject: a rejected record is archived and not redelivered.

setup_karafka

POISON = "poison"

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:received] << message.raw_payload

      if message.raw_payload == POISON
        mark_as_rejected(message)
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

good = DT.uuids(5)
produce_many(DT.topic, good + [POISON])

start_karafka_and_wait_until do
  DT[:accepted].sort == good.sort
end

# The good records are accepted and the poison one was delivered but never redelivered nor accepted
assert_equal good.sort, DT[:accepted].sort
assert_equal 1, DT[:received].count(POISON)
assert(!DT[:accepted].include?(POISON))
