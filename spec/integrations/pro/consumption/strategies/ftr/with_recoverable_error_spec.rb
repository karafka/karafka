# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Errors should be handled normally. There should be a backoff and retry and recovery should start
# from the message on which we broke. Throttling should have nothing to do with this.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset

      if message.offset == 7 && !@raised
        @raised = true

        raise StandardError, 'failure'
      end

      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    throttling(
      limit: 5,
      interval: 2_000
    )
  end
end

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 21
end

assert_equal(2, DT[0].count { |offset| offset == 7 })

checks = DT[0].dup
checks.delete_if { |offset| offset == 7 }
assert_equal [1], checks.group_by(&:itself).values.map(&:count).uniq
