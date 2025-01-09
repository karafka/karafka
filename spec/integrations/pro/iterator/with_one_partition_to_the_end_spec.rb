# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When iterating over the topic and not providing partitions, it should stream all the messages
# one after another and should use JSON.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

elements = DT.uuids(20).map { |data| { value: data }.to_json }
produce_many(DT.topic, elements)

# From beginning till the end
iterator = Karafka::Pro::Iterator.new(DT.topic)
i = 0
iterator.each do |message|
  assert_equal i, message.offset
  assert_equal message.raw_payload, elements[i]

  message.payload

  i += 1
end

assert_equal 20, i

# From middle till the end
i = 9
iterator = Karafka::Pro::Iterator.new(
  {
    DT.topic => { 0 => 9 }
  }
)

iterator.each do |message|
  assert_equal i, message.offset
  assert_equal message.raw_payload, elements[i]

  message.payload

  i += 1
end

assert_equal 20, i
