# frozen_string_literal: true

# Karafka should not resume when manual pause is in use for LRJ.
# Karafka should not throttle (unless in idle which would indicate pause lift) when manually paused
# After un-pause, Karafka may do a full throttle if the previous throttling time did not finish
# Offsets should not be changed

setup_karafka do |config|
  config.max_messages = 50
  config.pause_timeout = 2_000
  config.pause_max_timeout = 2_000
  config.pause_with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    if messages.count < 2 && @not_first.nil?
      @not_first = true
      return
    end

    DT[:paused] << messages.first.offset

    pause(messages.first.offset, 2_000)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    manual_offset_management true
    throttling(limit: 5, interval: 5_000)
    virtual_partitions(
      partitioner: ->(_msg) { rand(9) }
    )
  end
end

produce_many(DT.topic, DT.uuids(200))

start_karafka_and_wait_until do
  DT[:paused].size >= 3
end

assert_equal 0, fetch_first_offset
