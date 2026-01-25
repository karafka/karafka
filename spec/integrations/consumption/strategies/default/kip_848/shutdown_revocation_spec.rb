# frozen_string_literal: true

# Test KIP-848 to verify that the #revoked callback is not called during shutdown

setup_karafka(consumer_group_protocol: true) do |config|
  # Remove session timeout for this test
  config.kafka.delete(:"session.timeout.ms")
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] = true
  end

  def revoked
    DT[:revoked] = true
  end

  def shutdown
    DT[:shutdown] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

# Produce a message
produce(DT.topic, "test message")

start_karafka_and_wait_until do
  DT.key?(:consumed)
end

assert DT.key?(:consumed)
assert DT.key?(:shutdown)
assert !DT.key?(:revoked)
