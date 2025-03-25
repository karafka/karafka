# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When running on LRJ, ticking should happen alongside long processing because it is non blocking
# on proper periods when `during_pause` is set to true.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    start = Time.now.to_f
    sleep(10)
    DT[:consume] << (start..Time.now.to_f)
  end

  def tick
    produce_many(DT.topic, DT.uuids(1))
    DT[:ticks] << Time.now.to_f
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic(during_pause: true)
    long_running_job true
  end
end

start_karafka_and_wait_until do
  DT[:ticks].size >= 5
end

# There should be at least one tick parallel to consumption
assert DT[:consume].any? do |time_range|
  DT[:ticks].any? do |tick_time|
    time_range.include?(tick_time)
  end
end
