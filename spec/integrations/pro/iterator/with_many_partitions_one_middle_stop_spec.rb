# frozen_string_literal: true

# When iterating over the topic, we should be able to stop iteration of any partition we want
# without impacting the others even if we're in the middle of this partition.

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

iterator.each do |message, iterator|
  if message.partition.zero? && message.offset == 10
    iterator.stop_partition(0)

    next
  end

  partitioned_data[message.partition] << message
end

assert_equal partitioned_data.size, 10

# All data should be in order for the rest
partitioned_data.each do |partition, messages|
  offset = 0

  messages.each do |message|
    assert_equal offset, message.offset
    assert_equal message.raw_payload, partitioned_elements[partition][offset]

    offset += 1
  end

  assert_equal messages.size, partition.zero? ? 10 : 20
end
