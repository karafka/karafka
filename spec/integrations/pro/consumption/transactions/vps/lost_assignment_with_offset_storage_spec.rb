# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should NOT be able to mark as consumed within a transaction on a lost partition because the
# transaction is expected to fail.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 100
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    DT[:instances] << object_id

    sleep(0.1) until revoked?

    DT[:done] = true

    begin
      transaction do
        produce_async(topic: topic.name, payload: '1')
        mark_as_consumed(messages.last)
      end
    rescue Karafka::Errors::AssignmentLostError => e
      DT[:errors] << e
    end
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

assert_equal DT[:errors].size, DT[:instances].size
assert !DT[:errors].empty?
