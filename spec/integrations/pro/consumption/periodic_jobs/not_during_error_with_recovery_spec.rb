# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Ticking should work before and after the recovery but not during in the default setup.

setup_karafka(allow_errors: true) do |config|
  config.pause_timeout = 1_000
  config.pause_max_timeout = 1_500
  config.max_wait_time = 100
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    if DT[:errored].size < 5
      DT[:errored] << Time.now.to_f
      raise
    end

    DT[:post_error] << Time.now.to_f
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

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:post_error].size >= 2
end

DT[:ticks].each do |tick|
  assert (tick < DT[:errored].min) || (tick > DT[:post_error].min)
end
