# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When consumer is being used at least once, we should be able to see it when ticking

setup_karafka do |config|
  config.max_wait_time = 200
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def tick
    DT[:used] << used?
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic interval: 100
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[:used].count >= 5
end

assert DT[:used].uniq.size >= 1

assert(
  (DT[:used].uniq - [false, true]).empty?
)
