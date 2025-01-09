# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When iterating over the topic and not providing partitions, it should stream all the messages
# one after another and should use JSON also for case where there are multiple partitions.

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

partitioned_data = Hash.new { |h, v| h[v] = [] }

iterator = Karafka::Pro::Iterator.new(DT.topic)

iterator.each do |message|
  partitioned_data[message.partition] << message
end

# All partitions data should be included
assert_equal partitioned_data.size, 10

# All data should be in order
partitioned_data.each do |partition, messages|
  offset = 0

  messages.each do |message|
    assert_equal offset, message.offset
    assert_equal message.raw_payload, partitioned_elements[partition][offset]

    offset += 1
  end
end
