# frozen_string_literal: true

# When we mark as consumed outside of the transactional block but by using the transactional
# producer, in a case where we were not able to finalize the transaction it should not raise an
# error but instead should return false like the non-transactional one. This means we no longer
# have ownership of this partition.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] = true
    sleep(11)
    DT[:marking_result] = mark_as_consumed(messages.last)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(2))

start_karafka_and_wait_until do
  DT.key?(:marking_result)
end

assert_equal DT[:marking_result], false
