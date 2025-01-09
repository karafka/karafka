# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should use the same coordinator for all the jobs in a group

setup_karafka do |config|
  config.concurrency = 10
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:messages] << message.offset }

    DT[:coordinators_ids] << coordinator.object_id
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:messages].count >= 100
end

assert_equal 1, DT[:coordinators_ids].uniq.size
