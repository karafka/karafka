# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# By default ticking should not happen if we are in a recovery flow

setup_karafka(allow_errors: true) do |config|
  config.pause_timeout = 1_000
  config.pause_max_timeout = 1_500
  config.max_wait_time = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:started] << Time.now.to_f

    raise
  end

  def tick
    DT[:ticks] << Time.now.to_f
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
  sleep(10)
end

DT[:ticks].each do |tick|
  assert tick < DT[:started].min
end
