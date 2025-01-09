# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When running jobs without problems, there should always be only one attempt even if throttling
# occurs

setup_karafka do |config|
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:attempts] << coordinator.pause_tracker.attempt

    messages.each { |message| DT[0] << message.offset }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    throttling(limit: 5, interval: 2_000)
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

DT[:attempts].each { |attempt| assert_equal 1, attempt, DT[:attempts] }
