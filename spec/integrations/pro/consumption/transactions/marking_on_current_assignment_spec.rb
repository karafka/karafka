# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we mark with a transactional producer outside of the transactional block and we own the
# assignment, marking should return true

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] = true
    DT[:marking_result] = mark_as_consumed(messages.last)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(2))

start_karafka_and_wait_until do
  DT.key?(:marking_result)
end

assert_equal DT[:marking_result], true
