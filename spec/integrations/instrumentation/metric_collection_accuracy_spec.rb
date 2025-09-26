# frozen_string_literal: true

# Metric collection through instrumentation should be accurate and consistent,
# properly tracking counts, timings, and other measurement data.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      start_time = Time.now

      # Simulate processing with timing
      sleep(0.01)

      processing_time = Time.now - start_time

      # Store metrics directly
      DT[:processing_times] << processing_time
      DT[:message_sizes] << message.payload.bytesize
      DT[:partitions] << message.metadata.partition
      DT[:offsets] << message.metadata.offset
      DT[:messages_processed] << message.payload
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      deserializer ->(message) { message.raw_payload }
    end
  end
end

# Track consumer lifecycle events for accuracy
Karafka.monitor.subscribe('consumer.consumed') do |_event|
  DT[:lifecycle_events] << 'consumer.consumed'
end

# Produce test messages with known sizes
elements = %w[small medium_message this_is_a_longer_message_for_testing]
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:messages_processed].size >= 3 && DT[:lifecycle_events].size >= 1
end

# Verify metric accuracy
assert_equal 3, DT[:messages_processed].size
assert_equal 1, DT[:lifecycle_events].size

# Verify processing times are reasonable (between 0.01 and 0.1 seconds)
DT[:processing_times].each do |time|
  assert time >= 0.01
  assert time <= 0.1
end

# Verify message sizes match expected values
expected_sizes = elements.map(&:bytesize)
assert_equal expected_sizes.sort, DT[:message_sizes].sort

# Verify partition data
assert_equal [0, 0, 0], DT[:partitions]

# Verify offset ordering (should be sequential)
assert_equal DT[:offsets].sort, DT[:offsets]

# Verify consumer lifecycle events were captured
assert DT[:lifecycle_events].include?('consumer.consumed')
