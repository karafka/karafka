# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# If transaction fails we should mark as consumed only to the consecutive offset that was reached

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
      transaction do
        messages.each do |message|
          mark_as_consumed(message)
        end

        raise StandardError
      end
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

assert_equal DT[:metadata].uniq, %w[test-metadata]
assert_equal fetch_next_offset, 1
