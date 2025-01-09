# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we mark offsets in the middle of each, we should never end up with last marked

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 50
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if messages.count < 5

    mark_as_consumed(messages.to_a[messages.count / 2])

    DT[:lasts] << messages.last.offset
    DT[:batch] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    virtual_partitions(
      partitioner: ->(_msg) { rand(9) }
    )
  end
end

produce_many(DT.topic, DT.uuids(1000))

start_karafka_and_wait_until do
  DT[:batch].count > 5
end

# Since we do middle offset marking, this should never have the last from max batch
assert fetch_next_offset < DT[:lasts].max
