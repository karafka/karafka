# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 2
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    synchronize do
      DT[:sizes] << coordinator.virtual_offset_manager.groups.size
    end

    raise StandardError
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      filter VpStabilizer
      virtual_partitions(
        partitioner: ->(_msg) { rand(2) }
      )
    end
  end
end

produce_many(DT.topic, DT.uuids(200))

start_karafka_and_wait_until do
  DT[:sizes].size >= 10
end

assert DT[:sizes].max <= 3
