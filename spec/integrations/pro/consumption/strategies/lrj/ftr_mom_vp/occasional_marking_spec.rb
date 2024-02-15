# frozen_string_literal: true

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
    long_running_job true
    manual_offset_management true
    throttling(limit: 1, interval: 2_000)
    virtual_partitions(
      partitioner: ->(_msg) { rand(9) }
    )
  end
end

payloads = DT.uuids(50)
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
assert_equal DT[:marked].last + 1, fetch_first_offset
