# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When running LRJ and ticking, ticking is not synchronized with LRJ
# (unless synchronized via mutex). This means, that it should be possible to have a long living
# ticking that started when nothing was happening but meanwhile things started.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume] << Time.now.to_f
  end

  def tick
    start = Time.now.to_f
    produce_many(DT.topic, DT.uuids(1))
    sleep(10)
    DT[:ticks] << (start..Time.now.to_f)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
    long_running_job true
  end
end

start_karafka_and_wait_until do
  DT.key?(:ticks)
end

any = DT[:ticks].any? do |time_range|
  DT[:consume].any? do |tick_time|
    time_range.include?(tick_time)
  end
end

# There should be at least one tick parallel to consumption
assert any
