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
