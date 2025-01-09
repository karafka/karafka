# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we use current matching strategy on the given offset that can be materialized, it should
# use the most recently used offset metadata even if it was assigned to a different offset

setup_karafka do |config|
  config.max_messages = 100
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep((10 - messages.first.offset) / 10.to_f)

    messages.each do |message|
      time = Time.now.to_f
      DT[:times] << time
      mark_as_consumed!(message, time.to_s)
    end

    DT[:groups] << messages.map(&:offset)
  end

  def shutdown
    DT[:metadata] << offset_metadata(cache: false)
  end
end

DT[:iterator] = (0..9).cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    filter(VpStabilizer)
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next },
      offset_metadata_strategy: :current
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:groups].size >= 10
end

assert_equal DT[:times].max.to_s, DT[:metadata].last
