# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should be able to evenly distribute work when using a cycling partitioner
# Since we do not have multiple partitions/topics in this example, there are no locks around it,
# but in complex cases there should be a more complex cycling engine

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[object_id] << message.offset
    end
  end
end

CYCLE = (0..9).cycle

# A small note and explanation on cycle:
#
# This is how karafka distribution engine will convert the cycle to partitions:
#
# (0..9).map(&:to_s).map(&:sum).map {|x| x % 10 }
# [8, 9, 0, 1, 2, 3, 4, 5, 6, 7]
#
# This means, that you end up with exactly 10 VPs on a a cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(_) { CYCLE.next }
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT.data.values.map(&:size).sum >= 100
end

# Since Ruby hash function is slightly nondeterministic, not all the threads may always be used
# but in general more than 5 need to be always
assert DT.data.size >= 5

# On average we should have similar number of messages
sizes = DT.data.values.map(&:size)
average = sizes.sum / sizes.count
# Small deviations may be expected
assert average >= 8
assert average <= 12

# All data within partitions should be in order
DT.data.each_value do |offsets|
  previous_offset = nil

  offsets.each do |offset|
    unless previous_offset
      previous_offset = offset
      next
    end

    assert previous_offset < offset
  end
end
