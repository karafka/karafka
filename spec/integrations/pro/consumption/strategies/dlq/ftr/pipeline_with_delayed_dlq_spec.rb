# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# With delayed jobs with should be able to build a pipeline where we delay re-processing of
# messages when their processing fails and they are moved to DLQ.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      if message.offset == 10
        DT[:errored] << Time.now
        raise StandardError
      end

      mark_as_consumed message
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    DT[:retried] << Time.now
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
    # 15 seconds
    delay_by(15_000)
  end
end

elements = DT.uuids(15)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:retried)
end

assert DT[:retried].first - DT[:errored].first > 15
