# frozen_string_literal: true

# Share group (KIP-932) with `consumer_persistence` disabled builds a new consumer instance (and
# runs `#initialized` again) for every batch.

setup_karafka do |config|
  config.consumer_persistence = false
end

class Consumer < Karafka::ShareConsumer
  def initialized
    DT[:initialized] << id
  end

  def consume
    DT[:consumers] << id

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

elements = []

# Produce one record at a time once the previous one was consumed, so each lands in its own batch
start_karafka_and_wait_until do
  if DT[:accepted].size == elements.size && elements.size < 5
    elements << SecureRandom.uuid
    produce(DT.topic, elements.last)
  end

  DT[:accepted].size >= 5
end

assert_equal elements.sort, DT[:accepted].sort
assert_equal 5, DT[:consumers].size
assert_equal 5, DT[:consumers].uniq.size
assert_equal DT[:consumers], DT[:initialized]
