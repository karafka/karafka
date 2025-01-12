# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using transactions, we should be able to track the stored offset by taking the seek offset

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

Karafka.monitor.subscribe('consumer.consuming.transaction') do |event|
  DT[:seeks] << event[:caller].seek_offset
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    transaction do
      producer.produce_async(topic: DT.topic, payload: rand.to_s)
      mark_as_consumed(messages.first, messages.first.offset.to_s)
    end

    DT[:metadata] << offset_metadata
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[:seeks].size >= 5
end

assert DT[:seeks].last >= 10
