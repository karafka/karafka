# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using virtual partitions with eof, each VP should receive its own `#eofed` execution.

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def eofed
    DT[:eofed] << object_id
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    eofed true
    virtual_partitions(
      partitioner: lambda(&:raw_payload)
    )
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(100))
  sleep(5)

  DT[:eofed].uniq.size >= 8
end
