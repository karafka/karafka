# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When running jobs with non-recoverable errors, we should have the attempts count increased

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:attempts] << coordinator.pause_tracker.attempt

    raise(StandardError)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    throttling(limit: 10, interval: 1_000)
  end
end

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:attempts].size >= 10
end

assert (DT[:attempts] - (1..15).to_a).empty?, DT[:attempts]
