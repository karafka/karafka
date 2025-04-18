# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should not use the same coordinator for jobs from different partitions

setup_karafka do |config|
  config.concurrency = 10
  config.max_messages = 5
  config.initial_offset = 'latest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:messages] << message.offset }

    DT[:coordinators_ids] << coordinator.object_id
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    virtual_partitions(
      partitioner: ->(_) { rand }
    )
  end
end

start_karafka_and_wait_until do
  produce(DT.topic, '1', partition: 0)
  produce(DT.topic, '1', partition: 1)

  DT[:messages].size >= 100
end

assert_equal 2, DT[:coordinators_ids].uniq.size
