# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# If there is error after the transaction, the offset should be recorded with current metadata

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] << object_id

    if messages.first.offset.zero?
      transaction do
        mark_as_consumed(messages.first, 'test-metadata')
      end
    else
      sleep(1)

      transaction do
        messages.each do |message|
          mark_as_consumed(message, 'second')
        end
      end

      raise StandardError
    end
  end

  def shutdown
    DT[:metadata] << offset_metadata(cache: false)
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
  DT[:done].uniq.size >= 10
end

assert_equal DT[:metadata].last, 'second'
assert_equal fetch_next_offset, 10
