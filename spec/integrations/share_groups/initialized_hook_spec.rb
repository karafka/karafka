# frozen_string_literal: true

# Share group (KIP-932) consumers run `#initialized` once per consumer instance, before the first
# `#consume`, with the topic and partition already available and an empty messages batch.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def initialized
    DT[:initialized] << id
    DT[:topic] = topic
    DT[:partition] = partition
    DT[:messages] = messages
    @initialized = true
  end

  def consume
    DT[:consumers] << id
    DT[:initialized_before] << @initialized

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

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].size >= 10
end

assert_equal elements.sort, DT[:accepted].sort
assert_equal DT.topic, DT[:topic].name
assert_equal 0, DT[:partition]
assert DT[:messages].empty?
assert_equal DT[:consumers].uniq, DT[:initialized].uniq
assert_equal DT[:initialized].size, DT[:initialized].uniq.size
assert(DT[:initialized_before].all?)
