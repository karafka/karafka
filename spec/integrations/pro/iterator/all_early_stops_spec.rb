# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we stop processing early on all partitions, things should just stop.

setup_karafka

draw_routes do
  topic DT.topic do
    config(partitions: 10)
    active false
  end
end

partitioned_elements = {}

10.times do |partition|
  elements = DT.uuids(20).map { |data| { value: data }.to_json }
  produce_many(DT.topic, elements, partition: partition)
  partitioned_elements[partition] = elements
end

iterator = Karafka::Pro::Iterator.new(
  DT.topic,
  settings: {
    'auto.offset.reset': 'beginning',
    # In case something would be off with pausing, this will cause hang
    'enable.partition.eof': false
  }
)

iterator.each do |message, internal_iterator|
  internal_iterator.stop_partition(DT.topic, message.partition)
end

# No spec needed, things would hang if we would not stop
