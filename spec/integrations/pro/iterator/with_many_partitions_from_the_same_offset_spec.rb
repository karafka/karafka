# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When iterating over the topic from the same offset on all partitions, we should start from the
# expected on all and finish accordingly

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

iterator = Karafka::Pro::Iterator.new({ DT.topic => 10 })

iterator.each do |message|
  partitioned_data[message.partition] << message.offset
end

partitioned_data.each_value do |data|
  assert_equal (10..19).to_a, data
end
