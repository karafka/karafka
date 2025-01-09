# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we use exact matching strategy on the given offset that can be materialized, it should
# be used even if later we use a different higher that cannot be materialized

setup_karafka do |config|
  config.max_messages = 100
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(messages.first.offset / 10.to_f)

    if messages.first.offset.zero?
      mark_as_consumed!(messages.first, messages.first.offset.to_s)
      mark_as_consumed!(messages.to_a[1], messages.to_a[1].offset.to_s)
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
      offset_metadata_strategy: :exact
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:groups].size >= 10
end

assert_equal %w[0], DT[:metadata].uniq
