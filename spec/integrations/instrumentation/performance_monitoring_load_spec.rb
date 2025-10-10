# frozen_string_literal: true

# Performance monitoring should handle high-volume event emission without significant
# performance degradation or memory leaks during heavy load scenarios.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    # Simulate processing load without custom instrumentation
    messages.each do |message|
      DT[:processed] << message.raw_payload

      # Simulate work for performance testing
      5.times do |i|
        DT[:iterations] << i
        # Simulate some work
        sleep(0.001)
      end
    end
  end
end

draw_routes(Consumer)

# Track performance metrics
start_time = Time.now
event_count = 0
event_times = []

# Subscribe to consumer events to track performance
Karafka.monitor.subscribe('consumer.consumed') do |_event|
  event_count += 1
  event_times << Time.now.to_f
  DT[:consumer_events] << 1
end

# Subscribe to statistics to monitor performance
Karafka.monitor.subscribe('statistics.emitted') do |event|
  next unless event[:statistics]

  # Track memory and timing metrics
  stats = event[:statistics]
  (DT[:memory_usage] << stats['msg_cnt']) || 0
  DT[:stats_received] << 1
end

# Produce many messages to create load
elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:processed].size >= 100 && DT[:consumer_events].size >= 1
end

# Performance assertions
total_time = Time.now - start_time
assert DT[:processed].size == 100
assert DT[:consumer_events].size >= 1

# Verify processing completed in reasonable time (less than 30 seconds)
assert total_time < 30

# Verify iterations were processed
assert DT[:iterations].size >= 500
