# frozen_string_literal: true

# Karafka messages data should be as defined here

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[message.metadata.partition] << message
    end
  end
end

draw_routes(Consumer)

elements = Array.new(10) { SecureRandom.uuid }
elements.each { |number| produce(DataCollector.topic, number) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 10
end

DataCollector.data[0].each_with_index do |message, index|
  assert_equal Karafka::Messages::Message, message.class
  assert_equal Karafka::Messages::Metadata, message.metadata.class
  assert_equal String, message.raw_payload.class
  assert_equal Time, message.received_at.class
  assert_equal Time, message.metadata.received_at.class
  assert_equal 0, message.partition
  assert_equal Time, message.timestamp.class
  assert_equal index, message.offset
  assert_equal DataCollector.topic, message.topic
  assert_equal nil, message.key
  assert_equal false, message.deserialized?
end
