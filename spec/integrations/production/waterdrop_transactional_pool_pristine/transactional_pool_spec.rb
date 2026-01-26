# frozen_string_literal: true

# User should be able to use WaterDrop connection pool with transactional producers
# Each producer in the pool should have a unique transactional.id

require "karafka"
require "connection_pool"
require "securerandom"

# Setup WaterDrop global connection pool with transactional producers
WaterDrop::ConnectionPool.setup(size: 3, timeout: 5) do |config, index|
  config.kafka = {
    "bootstrap.servers": "127.0.0.1:9092",
    "transactional.id": "karafka-test-tx-#{index}"
  }
end

class TransactionalConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:processed_messages] << message.raw_payload

      # Use the global WaterDrop connection pool with transactions
      WaterDrop::ConnectionPool.with do |producer|
        # Track that we're using a pooled producer
        DT[:pool_usage] << producer.object_id

        # Extract transactional ID to verify uniqueness
        tx_id = producer.config.kafka[:"transactional.id"]
        DT[:transaction_ids] << tx_id

        # Use transaction to produce response message
        producer.transaction do
          producer.produce_sync(
            topic: "#{topic.name}-responses",
            payload: "processed-#{message.raw_payload}"
          )
        end
      end
    end
  end
end

setup_karafka

draw_routes(TransactionalConsumer)

# Send test messages using regular producer
3.times do |i|
  Karafka.producer.produce_sync(
    topic: DT.topic,
    payload: "message-#{i}"
  )
end

# Check pool stats before starting
pool_active = WaterDrop::ConnectionPool.active?
pool_stats = pool_active ? WaterDrop::ConnectionPool.stats : nil

start_karafka_and_wait_until do
  DT[:processed_messages].size >= 3
end

# Verify all messages were processed correctly
assert_equal 3, DT[:processed_messages].size
assert_equal %w[message-0 message-1 message-2], DT[:processed_messages]

# Verify the connection pool was used
assert DT[:pool_usage].size >= 3

# Verify pool stats
assert pool_active
assert_equal 3, pool_stats[:size] if pool_stats

# Verify transactional IDs are unique and follow expected pattern
unique_tx_ids = DT[:transaction_ids].uniq
assert unique_tx_ids.size >= 1
assert unique_tx_ids.size <= 3

# All transaction IDs should follow the pattern
DT[:transaction_ids].each do |tx_id|
  assert(
    tx_id.match?(/\Akarafka-test-tx-\d+\z/),
    "Transaction ID '#{tx_id}' doesn't match expected pattern"
  )
end
