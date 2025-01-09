# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When running on LRJ, ticking should not block and not cause max.poll.interval.ms to kick in

setup_karafka do |config|
  config.max_messages = 1
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def tick
    sleep(15)
    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
    long_running_job true
  end
end

# Will crash if ticking would block
start_karafka_and_wait_until do
  DT.key?(:done)
end
