# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to assign what we want and mark offsets in a transaction

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    transaction do
      messages.each { |message| mark_as_consumed(message) }
      produce_async(topic: DT.topic, payload: '1')
    end

    DT[:done] = true

    sleep(2)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # Not a VP case but we want to stabilize number of messages to prevent randomness
    filter ->(*_args) { VpStabilizer.new(10) }
    assign(true)
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert fetch_next_offset >= 10, fetch_next_offset
