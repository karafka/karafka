# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When marking in VP mode, when we mark only last message, the offset should not be comitted
# because we did not mark previous messages.
# This should apply only to the current batch though
# We make sure here that DLQ does not interact when no errors.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.size

    return if messages.size < 2

    messages.each do |message|
      next unless message.offset == 49

      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    long_running_job true
    dead_letter_queue topic: DT.topics[1]
    manual_offset_management(true)
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

produce_many(DT.topics[0], DT.uuids(50))

start_karafka_and_wait_until do
  DT[0].sum >= 50
end

assert fetch_next_offset < 49
