# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to maintain eof status when ticking

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    DT[:ticks] << eofed?
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
    eofed true
  end
end

start_karafka_and_wait_until do
  DT[:ticks].count >= 3
end

assert_equal DT[:ticks].uniq, [true]
