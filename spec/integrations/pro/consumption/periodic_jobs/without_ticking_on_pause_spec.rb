# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When periodic jobs are configured not to tick when partition is paused we should not tick then
# Keep in mind, LRJ always pauses so you won't have ticking on it if this is set like this

setup_karafka do |config|
  config.max_wait_time = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:iterations] << true

    if DT[:iterations].size >= 5
      pause(messages.first.offset, 100_000_000)
      DT[:started] = Time.now.to_f
    end
  end

  def tick
    DT[:ticks] << Time.now.to_f
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic(
      interval: 100,
      during_pause: false
    )
  end
end

start_karafka_and_wait_until do
  if DT[:iterations].size < 5
    produce_many(DT.topic, DT.uuids(1))
    sleep(1)
  end

  DT[:iterations].size >= 5 && DT.key?(:started) && sleep(5)
end

DT[:ticks].each do |tick|
  assert tick <= DT[:started]
end
