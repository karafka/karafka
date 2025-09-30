# frozen_string_literal: true

# Test that KIP-848 consumer group protocol works with basic consumption

setup_karafka do |config|
  # Use the new consumer protocol (KIP-848)
  config.kafka[:'group.protocol'] = 'consumer'
  # Remove settings that are not compatible with the new protocol
  config.kafka.delete(:'partition.assignment.strategy')
  config.kafka.delete(:'heartbeat.interval.ms')
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

# Produce test messages
produce_many(DT.topic, DT.uuids(20))

# Just verify basic consumption works with the new protocol
start_karafka_and_wait_until do
  DT[:consumed].size >= 20
end

assert_equal 20, DT[:consumed].size
assert_equal 20, DT[:consumed].uniq.size
