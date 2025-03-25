# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to subscribe to multiple topics with custom per topic negative lookups
# and they should work on all partitions

setup_karafka

draw_routes do
  topic DT.topics[0] do
    config(partitions: 2)
    active false
  end

  topic DT.topics[1] do
    config(partitions: 2)
    active false
  end
end

2.times do |topic_index|
  2.times do |partition|
    topic = DT.topics[topic_index]

    elements = DT.uuids(20).map { |data| { value: data }.to_json }
    produce_many(topic, elements, partition: partition)
  end
end

offsets = Hash.new { |h, k| h[k] = [] }

iterator = Karafka::Pro::Iterator.new(
  {
    DT.topics[0] => -5,
    DT.topics[1] => -10
  }
)

iterator.each do |message|
  offsets[message.topic][message.partition] ||= []
  offsets[message.topic][message.partition] << message.offset
end

assert_equal 2, offsets[DT.topics[0]].size
assert_equal 2, offsets[DT.topics[1]].size
assert_equal (15..19).to_a, offsets[DT.topics[0]][0]
assert_equal (15..19).to_a, offsets[DT.topics[0]][1]
assert_equal (10..19).to_a, offsets[DT.topics[1]][0]
assert_equal (10..19).to_a, offsets[DT.topics[1]][1]
