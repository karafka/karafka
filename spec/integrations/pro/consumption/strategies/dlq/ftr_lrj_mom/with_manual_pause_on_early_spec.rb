# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When pausing not on a last message, we should un-pause from it and not from the next incoming.

setup_karafka do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    return unless messages.count > 1

    messages.each do |message|
      DT[:offsets] << message.offset
    end

    return if messages.first.offset < 1

    pause(messages.first.offset, 2_000)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue topic: DT.topics[1], max_retries: 4
    long_running_job true
    manual_offset_management true
    throttling(limit: 5, interval: 5_000)
  end
end

payloads = DT.uuids(20)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  # This will only stop if our manual pause is more important than the regular automatic one
  DT[:offsets].size >= 40
end
