# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When iterating over partitions and starting from different offsets, we should reach the end
# and data should be as expected.

setup_karafka

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    active false
  end
end

partitioned_elements = {}

2.times do |partition|
  elements = DT.uuids(20).map { |data| { value: data }.to_json }
  produce_many(DT.topic, elements, partition: partition)
  partitioned_elements[partition] = elements
end

partitioned_data = Hash.new { |h, v| h[v] = [] }

iterator = Karafka::Pro::Iterator.new(
  {
    DT.topic => { 0 => 0, 1 => 10 }
  }
)

iterator.each do |message|
  partitioned_data[message.partition] << message
end

assert_equal partitioned_data.size, 2

# for partition 0 we start from beginning
offset = 0
partitioned_data[0].each do |message|
  assert_equal offset, message.offset
  assert_equal message.raw_payload, partitioned_elements[0][offset]

  offset += 1
end

assert_equal partitioned_elements[0].size, 20

# for partition 1 we start from the middle
offset = 10
partitioned_data[1].each do |message|
  assert_equal offset, message.offset
  assert_equal message.raw_payload, partitioned_elements[1][offset]

  offset += 1
end

assert_equal partitioned_data[1].size, 10, partitioned_data[1].size
