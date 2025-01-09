# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# In case we mark as consumed after a nested transactional error, it should not reset anything and
# go as planned

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done) && @done

    transaction do
      2.times do
        transaction do
          nil
        end
      rescue Karafka::Errors::TransactionAlreadyInitializedError
        DT[:done] << true
      end

      mark_as_consumed(messages.first)
    end

    @done = true
  end
end

DT[:iterator] = (0..9).cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter VpStabilizer
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next }
    )
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert fetch_next_offset > 0
