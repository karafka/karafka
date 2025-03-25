# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to pause from ticking

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    DT[:ticks] << true
    pause(:consecutive, 1_000_000_000)
    produce_many(DT.topic, DT.uuids(1))
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
  end
end

start_karafka_and_wait_until do
  DT[:ticks].size >= 3
end
