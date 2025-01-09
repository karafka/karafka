# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to mark as consumed when we own the assignment and produce messages but if
# at the finalization moment we lost the assignment, we should fail the transaction with the
# assignment lost error

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.max_messages = 2
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    DT[:done] = true

    begin
      transaction do
        mark_as_consumed(messages.last)
        sleep(0.1) until revoked?
        produce_async(topic: DT.topics[1], payload: '1')
      end
    rescue Karafka::Errors::AssignmentLostError
      DT[:error] = true
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    active(false)
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert DT.key?(:error)
assert_equal [], Karafka::Admin.read_topic(DT.topics[1], 0, 1)
assert_equal 0, fetch_next_offset
