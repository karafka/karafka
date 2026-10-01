# frozen_string_literal: true

# Share group (KIP-932) consumers can keep a long living buffer filled across many batches, as the
# same consumer instance is used for all of them.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def initialized
    @buffer = []
    @batches = 0
  end

  def consume
    @batches += 1

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end

    @buffer << messages.raw_payloads
  end

  # Transfer the buffer data outside of the consumer
  def shutdown
    DT[:batches] = @batches
    DT[:buffer] = @buffer
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

# Produce a few records at a time once the previous ones were consumed, so we get many batches
start_karafka_and_wait_until do
  if DT[:accepted].size == elements.size && elements.size < 20
    batch = DT.uuids(2)
    elements += batch
    produce_many(DT.topic, batch)
  end

  DT[:accepted].size >= 20
end

assert_equal 10, DT[:batches]
assert_equal elements, DT[:buffer].flatten
assert(DT[:buffer].all? { |sub| sub.size == 2 })
