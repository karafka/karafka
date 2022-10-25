# frozen_string_literal: true

# Karafka should be able to work with messages that have headers and all headers should have string
# keys

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [message.raw_payload, message.headers]
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(10)
elements.each { |data| produce(DT.topic, data, headers: { 'value' => data }) }

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal 1, DT.data.size
assert_equal 10, DT[0].size

DT[0].each do |element|
  assert_equal element[0], element[1].fetch('value')
  assert(element[1].keys.all? { |key| key.is_a?(String) })
end
