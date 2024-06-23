# frozen_string_literal: true

# We should NOT be able to mark as consumed within a transaction on a lost partition because the
# transaction is expected to fail.

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

    sleep(0.1) until revoked?

    begin
      transaction do
        produce_async(topic: topic.name, payload: '1')
        mark_as_consumed(messages.last)
      end
    rescue Karafka::Errors::AssignmentLostError => e
      DT[:error] = e
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert DT.key?(:error)
assert_equal [], Karafka::Admin.read_topic(DT.topic, 0, 1)
# We will have one message but this is read uncommitted so it will not appear in the above, plus
# the failed transaction control one
assert_equal 2, Karafka::Admin.read_watermark_offsets(DT.topic, 0).last
assert_equal 0, fetch_next_offset
