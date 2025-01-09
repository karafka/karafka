# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using manual offset management and not marking often, we should have a smooth processing
# flow without extra messages or anything.

setup_karafka do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end

    return unless messages.last.offset > 2 && !@marked

    @marked = true
    DT[:marked] << messages.last.offset
    mark_as_consumed(messages.last)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue topic: DT.topics[1], max_retries: 4
    long_running_job true
    manual_offset_management true
  end
end

payloads = DT.uuids(20)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

previous = -1

DT[0].each do |offset|
  assert_equal previous + 1, offset

  previous = offset
end

# We should start from the only offset marked as consumed + 1
assert_equal DT[:marked].first + 1, fetch_next_offset
