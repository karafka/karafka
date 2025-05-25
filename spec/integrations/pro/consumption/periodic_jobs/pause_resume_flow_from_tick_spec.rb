# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to control flow from ticking

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume] << messages.last.offset
  end

  def tick
    produce_many(DT.topic, DT.uuids(1))

    if @paused
      resume
      @paused = false
    else
      @paused = true
      pause(:consecutive, 1_000_000_000)
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
  end
end

start_karafka_and_wait_until do
  DT[:consume].size >= 3
end

assert_equal [0, 1, 2], DT[:consume][0..2]
