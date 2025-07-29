# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When running on LRJ, ticking should not happen alongside long processing if the long running
# job is running at the moment

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
    periodic(during_pause: true, interval: 1_000)
    long_running_job true
  end
end

start_karafka_and_wait_until do
  DT[:ticks].size >= 5
end

any = DT[:consume].any? do |time_range|
  DT[:ticks].any? do |tick_time|
    time_range.include?(tick_time)
  end
end

assert !any
