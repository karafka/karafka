# frozen_string_literal: true

# Karafka should be able to work with messages that have headers

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector[0] << [message.raw_payload, message.headers]
    end
  end
end

draw_routes(Consumer)

elements = Array.new(10) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data, headers: { 'value' => data }) }

start_karafka_and_wait_until do
  DataCollector[0].size >= 10
end

assert_equal 1, DataCollector.data.size
assert_equal 10, DataCollector[0].size

DataCollector[0].each do |element|
  assert_equal element[0], element[1].fetch('value')
end
