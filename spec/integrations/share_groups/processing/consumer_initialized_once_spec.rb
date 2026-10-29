# frozen_string_literal: true

# Share group (KIP-932) consumers run `#initialized` exactly once per instance, even when that
# instance consumes many batches split into many `max_messages` rounds.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def initialized
    DT[:initialized] << object_id
  end

  def consume
    DT[:consumed] << object_id

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      max_messages 2
      consumer Consumer
    end
  end
end

setup_share_group(DT.topic, DT.group, 2)

elements = []

2.times do |partition|
  payloads = DT.uuids(10)
  elements += payloads
  produce_many(DT.topic, payloads, partition: partition)
end

produced = 0

# Produce more over time so the same instances get batches from several polls as well
start_karafka_and_wait_until do
  if DT[:accepted].size == elements.size && produced < 4
    produced += 1
    payload = SecureRandom.uuid
    elements << payload
    produce(DT.topic, payload, partition: produced % 2)
  end

  DT[:accepted].size >= 24
end

assert_equal elements.sort, DT[:accepted].sort
assert DT[:consumed].size >= 14
assert_equal 2, DT[:initialized].size
assert_equal DT[:initialized].sort, DT[:consumed].uniq.sort
