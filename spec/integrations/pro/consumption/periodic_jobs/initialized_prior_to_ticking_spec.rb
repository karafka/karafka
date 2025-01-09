# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should run the initialized hook prior to ticking

setup_karafka

class Consumer < Karafka::BaseConsumer
  def initialized
    DT[:initialized] = Time.now.to_f
  end

  def consume; end

  def tick
    DT[:tick] = Time.now.to_f
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic(interval: 100)
  end
end

start_karafka_and_wait_until do
  DT.key?(:tick)
end

assert DT[:initialized] < DT[:tick]
