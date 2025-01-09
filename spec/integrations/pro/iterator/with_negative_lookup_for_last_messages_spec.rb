# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using negative lookups, we should get at most what we have requested

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

elements = DT.uuids(20).map { |data| { value: data }.to_json }
produce_many(DT.topic, elements)

# From beginning till the end
iterator = Karafka::Pro::Iterator.new(
  # Give me at most last 5 messages
  { DT.topic => { 0 => -5 } }
)

i = 15
iterator.each do |message|
  assert_equal i, message.offset
  assert_equal message.raw_payload, elements[i]

  message.payload

  i += 1
end

assert_equal i, 20
