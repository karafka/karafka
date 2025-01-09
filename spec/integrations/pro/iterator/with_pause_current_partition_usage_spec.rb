# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When iterating over the topics, we should be able to use the pause current to stop only the
# current topic partition processing

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
  end

  topic DT.topics[1] do
    active false
  end
end

partitioned_elements = {}

2.times do |index|
  topic = DT.topics[index]

  elements = DT.uuids(20).map { |data| { value: data }.to_json }
  produce_many(topic, elements)
  partitioned_elements[topic] = elements
end

partitioned_data = Hash.new { |h, v| h[v] = [] }

iterator = Karafka::Pro::Iterator.new(
  [DT.topics[0], DT.topics[1]]
)

iterator.each do |message, internal_iterator|
  if message.topic == DT.topics[0] && message.offset == 10
    internal_iterator.stop_current_partition

    next
  end

  partitioned_data[message.topic] << message
end

assert_equal partitioned_data.size, 2

# All data should be in order for the rest
partitioned_data.each do |partition, messages|
  offset = 0

  messages.each do |message|
    assert_equal offset, message.offset
    assert_equal message.raw_payload, partitioned_elements[partition][offset]

    offset += 1
  end

  assert_equal messages.size, messages.first.topic == DT.topics[0] ? 10 : 20
end
