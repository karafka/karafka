# frozen_string_literal: true

# User should be able to use WaterDrop default connection pool from within consumers
# This allows for producer pooling and reuse across different consumers

require "karafka"
require "connection_pool"
require "securerandom"

WaterDrop::ConnectionPool.setup(size: 3, timeout: 5) do |config|
  config.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
end

class PoolConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:processed_messages] << message.raw_payload

      # Use the global WaterDrop connection pool
      WaterDrop::ConnectionPool.with do |producer|
        # Track that we're using a pooled producer
        DT[:pool_usage] << producer.object_id

        # Produce a response message
        producer.produce_sync(
          topic: "#{topic.name}-responses",
          payload: "processed-#{message.raw_payload}"
        )
      end
    end
  end
end

setup_karafka

draw_routes(PoolConsumer)

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

assert_equal 3, DT[:processed_messages].size
assert_equal %w[message-0 message-1 message-2], DT[:processed_messages]
assert DT[:pool_usage].size >= 3
assert pool_active
assert_equal 3, pool_stats[:size] if pool_stats
