# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When periodic gets an assignment it should tick in intervals despite never having any data
# It should work as expected also for many partitions

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    raise unless messages.empty?

    DT[:ticks] << messages.metadata.partition
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    periodic true
  end
end

start_karafka_and_wait_until do
  DT[:ticks].count(0) >= 5 &&
    DT[:ticks].count(1) >= 5
end
