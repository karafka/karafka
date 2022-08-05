# frozen_string_literal: true

# Karafka should not use same consumer instance when consumer_persistence is set to false
# Each batch of data should be consumed with new instance

setup_karafka do |config|
  config.consumer_persistence = false
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << object_id
  end
end

draw_routes(Consumer)

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DT.topic, data) }

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert_equal 100, DT[0].uniq.size
