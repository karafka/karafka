# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should track offsets in transaction but only mark last on success

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    return seek(0) unless messages.size == 100

    return if DT.key?(:done)

    transaction do
      messages.each do |message|
        mark_as_consumed(message, message.offset.to_s)
      end
    end

    DT[:metadata] << offset_metadata
    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal '99', DT[:metadata].first

# +1 from 99 because of the transaction marker
assert_equal 100, fetch_next_offset
