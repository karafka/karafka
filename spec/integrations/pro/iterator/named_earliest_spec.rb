# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to use earliest reference

setup_karafka

draw_routes do
  topic DT.topics[0] do
    config(partitions: 2)
    active false
  end
end

2.times do |partition|
  topic = DT.topics[0]

  elements = DT.uuids(20).map { |data| { value: data }.to_json }
  produce_many(topic, elements, partition: partition)
end

offsets = Hash.new { |h, k| h[k] = [] }

iterator = Karafka::Pro::Iterator.new(
  {
    DT.topics[0] => {
      0 => :earliest,
      1 => 'earliest'
    }
  }
)

iterator.each do |message|
  offsets[message.topic][message.partition] ||= []
  offsets[message.topic][message.partition] << message.offset
end

assert_equal (0..19).to_a, offsets[DT.topics[0]][0]
assert_equal (0..19).to_a, offsets[DT.topics[0]][1]
