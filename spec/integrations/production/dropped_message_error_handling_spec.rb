# frozen_string_literal: true

# WaterDrop should handle dropped messages gracefully when Kafka is unavailable
# This spec demonstrates how to track dropped messages using the labeling API
# and error.occurred notifications

setup_karafka(allow_errors: true)

# Track dropped messages for verification
dropped_messages = []

# Track message payloads by label so we can retrieve them when dropped
message_payloads = {}

# Create a producer pointing to an invalid Kafka port
producer = ::WaterDrop::Producer.new do |config|
  config.deliver = true
  config.kafka = {
    'bootstrap.servers': 'localhost:9999',
    'message.timeout.ms': 1_000
  }
end

# Subscribe to error.occurred events to track dropped messages
producer.monitor.subscribe('error.occurred') do |event|
  # Handle dropped messages from librdkafka
  if event[:type] == 'librdkafka.dispatch_error'
    delivery_report = event[:delivery_report]
    label = delivery_report.label
    payload = message_payloads[label]

    # Track for verification
    dropped_messages << {
      label: label,
      payload: payload
    }
  end
end

# Try to send a message with a label to track it
message_payloads['test-label-1'] = 'test-message-content'
handler1 = producer.produce_async(
  topic: 'test-topic',
  payload: 'test-message-content',
  label: 'test-label-1'
)

# Send another message with different label
message_payloads['test-label-2'] = 'another-message'
handler2 = producer.produce_async(
  topic: 'test-topic',
  payload: 'another-message',
  label: 'test-label-2'
)

# Wait for delivery reports to be processed
handler1.wait(raise_response_error: false)
handler2.wait(raise_response_error: false)

# Close producer to flush any pending operations
producer.close

# Verify that both messages were dropped
assert_equal 2, dropped_messages.size
assert_equal 'test-label-1', dropped_messages[0][:label]
assert_equal 'test-message-content', dropped_messages[0][:payload]
assert_equal 'test-label-2', dropped_messages[1][:label]
assert_equal 'another-message', dropped_messages[1][:payload]
