# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to resume from ticking

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume] << messages.last.offset

    # This will ensure we won't resume automatically
    pause(:consecutive, 1_000_000_000)
  end

  def tick
    resume
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
  end
end

produce_many(DT.topic, DT.uuids(10))

# If resume from ticking will not work, this will hang
start_karafka_and_wait_until do
  DT[:consume].count >= 3
end

assert_equal [0, 1, 2], DT[:consume][0..2]
