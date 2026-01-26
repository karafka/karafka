# frozen_string_literal: true

# Karafka should handle different message sizes properly

setup_karafka do |config|
  # Set reasonable limits for testing
  config.kafka[:"message.max.bytes"] = 50_000 # 50KB - allow larger messages for testing
  config.kafka[:"fetch.message.max.bytes"] = 50_000 # 50KB
end

class MaxSizeConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << {
        size: message.raw_payload.bytesize,
        partition: message.metadata.partition,
        offset: message.metadata.offset
      }
    end
  end
end

draw_routes(MaxSizeConsumer)

# Test different message sizes to verify handling
messages_to_test = [
  { name: "small", size: 1_000, payload: "x" * 1_000 }, # 1KB
  { name: "medium", size: 10_000, payload: "x" * 10_000 }, # 10KB
  { name: "large", size: 30_000, payload: "x" * 30_000 } # 30KB
]

messages_to_test.each do |test_msg|
  produce(DT.topic, test_msg[:payload])
end

start_karafka_and_wait_until do
  DT[:consumed].size >= 3
end

# Verify all messages were consumed correctly
assert_equal 3, DT[:consumed].size, "Should consume all test messages"

# Verify message sizes are correct
consumed_sizes = DT[:consumed].map { |msg| msg[:size] }.sort
expected_sizes = messages_to_test.map { |msg| msg[:size] }.sort

assert_equal expected_sizes, consumed_sizes, "Message sizes should match expected sizes"
