# frozen_string_literal: true

# Test KIP-848 with regular (non-LRJ) consumption to ensure that when
# max.poll.interval.ms is exceeded, the consumer is properly kicked out
# and revoked callbacks are triggered

setup_karafka(allow_errors: true) do |config|
  # Use the new consumer protocol (KIP-848)
  config.kafka[:'group.protocol'] = 'consumer'
  # Remove settings that are not compatible with KIP-848
  config.kafka.delete(:'partition.assignment.strategy')
  config.kafka.delete(:'heartbeat.interval.ms')
  config.kafka.delete(:'session.timeout.ms')
  # Very short max poll interval for faster testing
  config.kafka[:'max.poll.interval.ms'] = 5_000
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:started] = true
    DT[:partition] = messages.metadata.partition

    # Simulate work that exceeds max.poll.interval.ms
    # This should cause the consumer to be kicked out
    sleep(10)

    # Check if we've been revoked
    DT[:revoked_detected] = revoked?
    DT[:consume_finished] = true
  end

  def revoked
    DT[:revoked_method_called] = true
  end
end

draw_routes(Consumer)

produce(DT.topic, 'test1', partition: 0)

start_karafka_and_wait_until do
  DT.key?(:revoked_detected)
end

# Assertions to verify KIP-848 revocation detection works on rebalance

# The #revoked lifecycle method should be called during rebalance
assert DT[:revoked_method_called]

# The #revoked? method should detect revocation during consume
assert DT[:revoked_detected]
