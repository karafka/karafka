# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should be able to use transactions with offset storage with metadata

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    transaction do
      producer.produce_async(topic: DT.topic, payload: rand.to_s)
      mark_as_consumed(messages.first, messages.first.offset.to_s)
    end

    DT[:metadata] << offset_metadata
    DT[:done] = true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal '0', DT[:metadata].first
