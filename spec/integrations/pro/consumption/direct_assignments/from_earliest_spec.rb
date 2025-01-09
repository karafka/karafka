# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to assign to ourselves direct ownership of partitions we are interested in

setup_karafka

DT[:partitions] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:partitions] << partition
  end

  def shutdown
    DT[:shutdowns] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 2)
    assign(0, 1)
  end
end

2.times do |i|
  elements = DT.uuids(10)
  produce_many(DT.topic, elements, partition: i)
end

start_karafka_and_wait_until do
  DT[:partitions].size >= 2
end

assert_equal 2, DT[:shutdowns].count
