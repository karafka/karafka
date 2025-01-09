# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using virtual partitions and tracking errors, under collapse they should be present
# collectively from many partitions

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 10
end

E1 = Class.new(StandardError)
E2 = Class.new(StandardError)

class Consumer < Karafka::BaseConsumer
  def consume
    if collapsed?
      DT[:errors_collapsed] << errors_tracker.to_a.dup
    else
      synchronize do
        DT[:switch] << 1

        raise (DT[:switch].size % 2).zero? ? E1 : E2
      end
    end
  end
end

DT[:iterator] = (0..9).cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next }
    )
    filter VpStabilizer
  end
end

produce_many(DT.topic, DT.uuids(500))

start_karafka_and_wait_until do
  DT[:errors_collapsed].size >= 2
end

assert_equal DT[:errors_collapsed].map(&:size).uniq, [10]
assert_equal DT[:errors_collapsed].map(&:to_a).flatten.map(&:class).uniq.sort_by(&:to_s), [E1, E2]
