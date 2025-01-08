# frozen_string_literal: true

# We should be able to clean messages while keeping the metadata

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
  message.clean!(metadata: false)
  # If all would be cleaned, below would fail
  message.key
  message.headers

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
