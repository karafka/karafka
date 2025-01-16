# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When a transaction is aborted, it should also fire the consuming event as abort similar to
# ActiveRecord transaction does not propagate and is handled internally, thus no error.

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

Karafka.monitor.subscribe('consumer.consuming.transaction') do
  DT[:occurred] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    transaction do
      mark_as_consumed(messages.last)
      DT[:done] = true

      raise(WaterDrop::AbortTransaction)
    end

    DT[:seek_offset] = seek_offset
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal 0, fetch_next_offset
assert DT.key?(:occurred)
assert_equal 0, DT[:seek_offset]
