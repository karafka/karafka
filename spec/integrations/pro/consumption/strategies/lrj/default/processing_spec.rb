# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When a job is marked as lrj, it should keep running longer than max poll interval and all
# should be good. It should continue processing after resume and should pick up next messages

setup_karafka do |config|
  config.max_messages = 1
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Ensure we exceed max poll interval, if that happens and this would not work async we would
    # be kicked out of the group
    sleep(15)

    DT[0] << messages.first.raw_payload
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

payloads = DT.uuids(2)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 2
end

assert_equal payloads, DT[0]
