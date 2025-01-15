# frozen_string_literal: true

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
  end
end

draw_routes(Consumer)
produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal 0, fetch_next_offset
assert DT.key?(:occurred)
